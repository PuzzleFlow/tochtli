module ServiceBase
	class ReplyQueue
		attr_reader :connection, :logger
		delegate :name, :to => :@queue

		def initialize(rabbit_connection, logger=nil)
			@connection = rabbit_connection
			@logger = logger || rabbit_connection.logger
			@queue = @connection.channel.queue('', exclusive: true, auto_delete: true)
			@queue.bind @connection.exchange, routing_key: @queue.name

			@consumer = @queue.subscribe(block: false, &method(:on_delivery))
			@message_handlers = {}
			@message_timeout_threads = {}
		end

		def register_message_handler(message, handler=nil, timeout=nil, &block)
			@message_handlers[message.id] = handler || block
			if timeout
				timeout_thread = Thread.start do
					sleep timeout
					logger.warn "[#{Time.now} AMQP] TIMEOUT on message '#{message.id}' timeout: #{timeout}"
					handle_timeout message
				end
				@message_timeout_threads[message.id] = timeout_thread
			end
		end

		def on_delivery(delivery_info, metadata, payload)
			reply_class = metadata.type.camelize.constantize
			reply = reply_class.new({}, metadata)
			reply.from_json payload, false

			logger.debug "[#{Time.now} AMQP] Replay for #{reply.properties.correlation_id}: #{reply.inspect}"

			handle_reply reply

		rescue Exception
			logger.error $!
			logger.error $!.backtrace.join("\n")
		end

		def handle_reply(reply)
			if (handler = @message_handlers.delete(reply.properties.correlation_id))
				if (timeout_thread = @message_timeout_threads.delete(reply.properties.correlation_id))
					timeout_thread.kill
					timeout_thread.join # make sure timeout thread is dead
				end

				unless reply.is_a?(ServiceBase::ErrorMessage)

					begin

						handler.call(reply)

					rescue Exception
						logger.error $!
						logger.error $!.backtrace.join("\n")
						handler.on_error($!)
					end

				else
					handler.on_error(reply)
				end

			else
				logger.error "[ServiceBase::ReplyQueue] Unexpected message delivery '#{reply.properties.correlation_id}':\n\t#{reply.inspect})"
			end
		end

		def handle_timeout(original_message)
			if (handler = @message_handlers.delete(original_message.id))
				@message_timeout_threads.delete(original_message.id)
				handler.on_timeout original_message
			else
				raise "Internal error, timeout handler not found for message: #{original_message.id}, #{original_message.inspect}"
			end
		end

		class Consumer < ::Bunny::Consumer
		end
	end
end
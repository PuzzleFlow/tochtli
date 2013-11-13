module ServiceBase
	module Test
		class Integration < ActiveSupport::TestCase
			RabbitClient.rabbit_config = {:exchange_name => "puzzleflow.tests"}
			ControllerManager.queue_name_prefix = 'tests/'
			ControllerManager.queue_durable = false
			ControllerManager.queue_auto_delete = true

			setup do
				@client = ServiceBase::RabbitClient.new
				@connection = @client.rabbit_connection
				@controller_manager = ServiceBase::ControllerManager.instance
				@controller_manager.start(@connection)

				# Reply support
				@mutex = Mutex.new
				@cv = ConditionVariable.new
			end

			teardown do
				@controller_manager.stop
			end

			private

			def publish(message, options={})
				@reply = nil
				timeout = options.fetch(:timeout, 1.0)
				@reply_message_class = options[:expect]
				@reply_handler = options[:reply_handler]

				if @reply_message_class || @reply_handler
					handler = @reply_handler || method(:synchronous_reply_handler)
					@client.reply_queue.register_message_handler message, &handler
				end

				@client.publish message

				if @reply_message_class && !@reply_handler
					synchronous_timeout_handler(message, timeout)
				end
			end

			def synchronous_reply_handler(reply)
				@reply = reply
				assert_kind_of @reply_message_class, @reply, "Unexpected reply"
				@mutex.synchronize { @cv.signal }
			end

			def synchronous_timeout_handler(message, timeout)
				@mutex.synchronize { @cv.wait(@mutex, timeout) }

				raise "Reply on #{message.class.name} timeout" unless @reply
				raise @reply.message if @reply.is_a?(ServiceBase::ErrorMessage)

				@reply
			end
		end
	end
end
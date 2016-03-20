module Tochtli
  class ReplyQueue
    attr_reader :connection, :logger, :queue

    def initialize(rabbit_connection, logger=nil)
      @connection              = rabbit_connection
      @logger                  = logger || rabbit_connection.logger
      @message_handlers        = {}
      @message_timeout_threads = {}

      subscribe
    end

    def name
      @queue.name
    end

    def subscribe
      channel  = @connection.channel
      exchange = @connection.exchange

      @queue               = channel.queue('', exclusive: true, auto_delete: true)
      @original_queue_name = @queue.name
      @queue.bind exchange, routing_key: @queue.name

      @consumer = Consumer.new(self, channel, @queue)
      @consumer.on_delivery(&method(:on_delivery))

      @queue.subscribe_with(@consumer)
    end

    def reconnect(channel)
      if @queue
        channel.connection.logger.debug "Recovering reply queue binding (original: #{@original_queue_name}, current: #{@queue.name})"

        # Re-bind queue after name change (auto-generated new on server has been re-generated)
        exchange = @connection.create_exchange(channel)
        @queue.unbind exchange, routing_key: @original_queue_name
        @queue.bind exchange, routing_key: @queue.name
      end

      @original_queue_name = @queue.name
    end

    def register_message_handler(message, handler=nil, timeout=nil, &block)
      @message_handlers[message.id] = handler || block
      if timeout
        timeout_thread                       = Thread.start do
          sleep timeout
          logger.warn "[#{Time.now} AMQP] TIMEOUT on message '#{message.id}' timeout: #{timeout}"
          handle_timeout message
        end
        @message_timeout_threads[message.id] = timeout_thread
      end
    end

    def on_delivery(delivery_info, metadata, payload)
      class_name       = metadata.type.camelize.gsub(/[^a-zA-Z0-9\:]/, '_') # basic sanity
      reply_class      = get_constant(class_name)
      reply            = reply_class.new({}, metadata)
      attributes       = JSON.parse(payload)
      reply.attributes = attributes

      logger.debug "[#{Time.now} AMQP] Replay for #{reply.properties.correlation_id}: #{reply.inspect}"

      handle_reply reply

    rescue StandardError
      logger.error $!
      logger.error $!.backtrace.join("\n")
    end

    def handle_reply(reply, correlation_id=nil)
      correlation_id ||= reply.properties.correlation_id if reply.is_a?(Tochtli::Message)
      raise ArgumentError, "Correlated message ID expected" unless correlation_id
      if (handler = @message_handlers.delete(correlation_id))
        if (timeout_thread = @message_timeout_threads.delete(correlation_id))
          timeout_thread.kill
          timeout_thread.join # make sure timeout thread is dead
        end

        if !reply.is_a?(Tochtli::ErrorMessage) && !reply.is_a?(StandardError)

          begin

            handler.call(reply)

          rescue StandardError
            logger.error $!
            logger.error $!.backtrace.join("\n")
            handler.on_error($!)
          end

        else
          handler.on_error(reply)
        end

      else
        logger.error "[Tochtli::ReplyQueue] Unexpected message delivery '#{correlation_id}':\n\t#{reply.inspect})"
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

    private

    def get_constant(class_name)
      class_name.split('::').inject(Object) do |mod, class_name|
        mod.const_get(class_name)
      end
    end


    class Consumer < ::Bunny::Consumer
      def initialize(reply_queue, *args)
        super(*args)
        @reply_queue = reply_queue
      end

      def recover_from_network_failure
        super
        @reply_queue.reconnect(@channel)
      rescue StandardError
        logger = channel.connection.logger
        logger.error $!
        logger.error $!.backtrace.join("\n")
        raise
      end
    end
  end
end

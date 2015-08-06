module Tochtli
  class RabbitClient

    attr_reader :rabbit_connection

    def initialize(rabbit_connection=nil, logger=nil)
      if rabbit_connection
        @rabbit_connection = rabbit_connection
      else
        @rabbit_connection = Tochtli::RabbitConnection.open(nil, logger: logger)
      end
      @logger = logger || @rabbit_connection.logger
    end

    def publish(message, options={})
      raise InvalidMessageError.new(message.errors.join(", "), message) if message.invalid?

      @logger.debug "[#{Time.now} AMQP] Publishing message #{message.id} to #{message.routing_key}"

      reply_queue        = @rabbit_connection.reply_queue
      options[:reply_to] = reply_queue.name
      if (message_handler = options[:handler])
        reply_queue.register_message_handler message, message_handler, options[:timeout]
      end
      @rabbit_connection.publish message.routing_key, message, options
    end

    def wait_for_confirms
      @rabbit_connection.channel.wait_for_confirms
    end

    def reply_queue(*args)
      rabbit_connection.reply_queue(*args)
    end
  end
end
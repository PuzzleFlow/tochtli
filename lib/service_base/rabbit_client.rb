module ServiceBase
	class RabbitClient

		cattr_accessor :rabbit_config
		self.rabbit_config = nil

		attr_reader :rabbit_connection, :reply_queue, :configuration_store

		def initialize(rabbit_connection=nil)
			if rabbit_connection
				@rabbit_connection = rabbit_connection
			else
				@rabbit_connection = ServiceBase::RabbitConnection.new(self.class.rabbit_config)
				@rabbit_connection.connect
			end
			@reply_queue = ServiceBase::ReplyQueue.new(self.rabbit_connection)
			@configuration_store = ServiceBase::Configuration::ActiveRecordStore.new
		end

		def publish(message, options={})
			options[:reply_to] = @reply_queue.name
			if (message_handler = options[:handler])
				@reply_queue.register_message_handler message, message_handler, options[:timeout]
			end
			@rabbit_connection.publish message.routing_key, message, options
		end
	end
end
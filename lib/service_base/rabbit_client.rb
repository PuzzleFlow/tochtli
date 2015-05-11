module ServiceBase
	class RabbitClient

		cattr_accessor :rabbit_config
		self.rabbit_config = nil

		attr_reader :rabbit_connection

		delegate :reply_queue, to: :rabbit_connection

		def initialize(rabbit_connection=nil, logger=nil)
			if rabbit_connection
				@rabbit_connection = rabbit_connection
			else
				config_name = self.class.rabbit_config
				config_name = Rails.env if !config_name && defined?(Rails)
				raise "ServiceBase::RabbitClient.rabbit_config is not set. Please setup configuration name." unless config_name
				@rabbit_connection = ServiceBase::RabbitConnection.open(config_name, logger: logger)
			end
			@logger = logger || @rabbit_connection.logger
		end

		def publish(message, options={})
			raise InvalidMessageError.new(message.errors.full_messages.join(", "), message) if message.invalid?

			@logger.debug "[#{Time.now} AMQP] Publishing message #{message.id} to #{message.routing_key}"

			reply_queue = @rabbit_connection.reply_queue
			options[:reply_to] = reply_queue.name
			if (message_handler = options[:handler])
				reply_queue.register_message_handler message, message_handler, options[:timeout]
			end
			@rabbit_connection.publish message.routing_key, message, options
		end

		def publish_and_wait(message, timeout, options={})
			mutex = Mutex.new
			cv    = ConditionVariable.new
			if options[:handler]
				options[:handler].cv = cv rescue nil
				options[:handler].mutex = mutex rescue nil
			end
			Thread.new do
				publish message, options
			end

			mutex.synchronize { cv.wait(mutex, timeout.to_f) }
		end
	end
end
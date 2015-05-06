module ServiceBase
	class BaseClient
		attr_reader :rabbit_client, :logger

		class_attribute :singleton_instance
		self.singleton_instance = nil

		# Singleton for controllers
		def self.instance(*args)
			unless self.singleton_instance
				self.singleton_instance = new(*args)
			end
			self.singleton_instance
		end

		# Reset singleton instance (useful for tests)
		def self.force_instance(*args)
			self.singleton_instance = nil
			instance(*args)
		end

		def initialize(rabbit_client_or_connection = nil, logger = nil)
			case rabbit_client_or_connection
				when ServiceBase::RabbitClient
					@rabbit_client = rabbit_client_or_connection
				when ServiceBase::RabbitConnection
					@rabbit_client = ServiceBase::RabbitClient.new(rabbit_client_or_connection, logger)
				when NilClass
					@rabbit_client = ServiceBase::RabbitClient.new(nil, logger)
				else
					raise ArgumentError, "ServiceBase::RabbitClient or ServiceBase::RabbitConnection expected, got: #{rabbit_client_or_connection.class}"
			end
			@logger = logger
		end

		class ClientError < Struct.new(:type, :message)
		end

		class MessageHandler
			def initialize(external_handler)
				@external_handler = external_handler
			end

			def on_timeout(original_message)
				@external_handler.on_timeout
			end

			def on_error(error_message)
				if error_message.is_a?(Exception)
					@external_handler.on_error error_message.class.name, error_message.message
				else
					@external_handler.on_error error_message.error, error_message.message
				end
			end
		end

		class SyncMessageHandler
			include MonitorMixin
			attr_reader :reply, :error

			def initialize
				super # initialize monitor
				@cv = new_cond
			end

			def wait(timeout)
				synchronize do
					@cv.wait(timeout) unless handled?
				end
				on_timeout unless handled?
			end

			def wait!(timeout)
				wait(timeout)
				raise_error unless @reply
				@reply
			end

			def handled?
				@reply || @error
			end

			def on_timeout(original_message=nil)
				synchronize do
					@error = ClientError.new("Timeout", original_message ? "Unable to send message: #{original_message.inspect}" : "Service is not responding")
					@cv.signal
				end
			end

			def on_error(error_message)
				synchronize do
					if error_message.is_a?(Exception)
						@error = ClientError.new(error_message.class.name, error_message.message)
					else
						@error = ClientError.new(error_message.error, error_message.message)
					end
					@cv.signal
				end
			end

			def call(reply)
				synchronize do
					@reply = reply
					@cv.signal
				end
			end

			def raise_error
				error = self.error || ClientError.new("ClientError", "Unknown Error")
				raise "[#{error.type}] #{error.message}"
			end
		end

	end
end


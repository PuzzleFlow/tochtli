module ServiceBase
	module Test
		class Controller < ServiceBase::Test::TestCase
			class_attribute :controller_class

			def self.tests(controller_class)
				self.controller_class = controller_class
			end

			setup do
				@cache = ActiveSupport::Cache::MemoryStore.new
				@logger = ServiceBase.logger
				self.controller_class.setup
				@dispatcher = ServiceBase::BaseController::Dispatcher.new(self.controller_class, @connection, @cache, @logger)
			end

			teardown do
				self.controller_class.stop
			end

			def publish(message)
				@message_index += 1
				delivery_info = TestDeliveryInfo.new(message.routing_key)
				properties = TestMessageProperties.new("test.reply", @message_index)
				payload = message.to_json

				@message, @reply = nil

				unless @dispatcher.process_message(delivery_info, properties, payload)
					if (reply = @connection.publications.first) && reply[:message].is_a?(ServiceBase::ErrorMessage)
						raise "Process error: #{reply[:message].message}"
					else
						raise "Message #{message.class.name} not processed by #{self.controller_class}."
					end
				end

				reply = @connection.publications.first
				if reply && reply[:routing_key] == "test.reply" && reply[:correlation_id] == @message_index
					@connection.publications.shift
					@reply = reply[:message]
				end
			end

		end
	end
end

module ServiceBase
	class TestCase < ActiveSupport::TestCase
		class_attribute :controller_class

		def self.tests(controller_class)
			self.controller_class = controller_class
		end

		setup do
			@connection = TestRabbitConnection.new
			@cache = ActiveSupport::Cache::MemoryStore.new
			@controller = self.class.controller_class.new(@connection, @cache)
			@message_index = 0
		end

		def publish(message)
			@message_index += 1
			delivery_info = TestDeliveryInfo.new(message.routing_key)
			properties = TestMessageProperties.new("test.reply", @message_index)
			payload = message.to_json

			@reply = nil
			@controller.cleanup

			unless @controller.process_message(delivery_info, properties, payload)
				raise "Message #{message.class.name} not processed by #{@controller}."
			end

			reply = @connection.publications.first
			if reply && reply[:routing_key] == "test.reply" && reply[:correlation_id] == @message_index
				@connection.publications.shift
				@reply = reply[:message]
			end
		end

	end

	class TestRabbitConnection
		attr_reader :channel, :exchange, :publications

		def initialize
			@channel = TestRabbitChannel.new
			@exchange = TestRabbitExchange.new
			@publications = []
		end

		def publish(routing_key, message, options={})
			@publications << options.merge(routing_key: routing_key, message: message)
		end
	end

	class TestRabbitChannel

	end

	class TestRabbitExchange

	end

	class TestDeliveryInfo
		attr_reader :routing_key

		def initialize(routing_key)
			@routing_key = routing_key
		end
	end

	class TestMessageProperties
		attr_reader :reply_to, :correlation_id

		def initialize(reply_to, correlation_id=nil)
			@reply_to = reply_to
			@correlation_id = correlation_id
		end
	end
end
module ServiceBase
	module Test
		class TestCase < ActiveSupport::TestCase

			setup do
				@connection = TestRabbitConnection.new
				@message_index = 0
			end

			def assert_published(message_class, attributes={})
				publication = @connection.get_publication
				assert_not_nil publication, "No message published"
				@message = publication[:message]
				assert_kind_of message_class, @message
				attributes.each do |attr_name, value|
					assert_equal value, @message.send(attr_name), "Message attribute :#{attr_name} value does not match"
				end
				yield @message if block_given?
				@message
			end

			def expect_published(message_class, attributes={})
				@connection.callback do
					assert_published message_class, attributes
					yield @message
				end
			end

		end

		class TestRabbitConnection
			attr_reader :channel, :exchange, :publications

			def initialize
				@channel = TestRabbitChannel.new
				@exchange = TestRabbitExchange.new
				@publications = []
				@queues = {}
			end

			def reply_queue
				@reply_queue ||= ServiceBase::ReplyQueue.new(self)
			end

			def publish(routing_key, message, options={})
				@publications << options.merge(routing_key: routing_key, message: message)
				run_callback
			end

			def get_publication
				@publications.shift
			end

			def callback(&block)
				@callback = block
			end

			def run_callback
				if @callback
					@callback.call
					@callback = nil
				end
			end

			def logger
				Logger.new(STDOUT)
			end

			def queue(name=nil, routing_keys=[], options={})
				queue = @queues[name]
				unless queue
					@queues[name] = queue = TestQueue.new(name, options)
				end
				queue
			end

			def queue_exists?(name)
				@queues.has_key?(name)
			end
		end

		class TestRabbitChannel
			def queue(name, options={})
				TestQueue.new(name, options)
			end
		end

		class TestRabbitExchange
		end

		class TestQueue
			attr_reader :name, :options, :routing_key

			def initialize(name, options)
				@name = name
				@options = options
			end

			def bind(exchange, options)
				@routing_key = options[:routing_key]
			end

			def subscribe(*args)
			end
		end

		class TestDeliveryInfo
			attr_reader :routing_key, :exchange

			def initialize(routing_key, exchange='TestExchange')
				@routing_key = routing_key
				@exchange = exchange
			end

			def [](key)
				send(key)
			end
		end

		class TestMessageProperties
			attr_reader :reply_to, :message_id, :correlation_id

			def initialize(reply_to, message_id=nil, correlation_id=nil)
				@reply_to = reply_to
				@message_id = message_id
				@correlation_id = correlation_id
			end

			def [](key)
				send(key)
			end
		end

		class TestMessageHandler
			attr_reader :reply, :timeout_message

			def call(reply)
				@reply = reply
			end

			def on_timeout(original_message=nil)
				@timeout_message = original_message
			end
		end
	end
end
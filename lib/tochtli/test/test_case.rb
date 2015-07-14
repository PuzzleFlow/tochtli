module Tochtli
  module Test
    class TestCase < Minitest::Test

      def before_setup
        super
        @connection    = TestRabbitConnection.new
        @message_index = 0
      end

      def assert_published(message_class, attributes={})
        publication = @connection.get_publication
        refute_nil publication, "No message published"
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
        @channel      = TestRabbitChannel.new(self)
        @exchange     = TestRabbitExchange.new
        @publications = []
        @queues       = {}
      end

      def exchange_name
        @exchange.name
      end

      def reply_queue
        @reply_queue ||= Tochtli::ReplyQueue.new(self)
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
          @queues[name] = queue = TestQueue.new(@channel, name, options)
        end
        queue
      end

      def queue_exists?(name)
        @queues.has_key?(name)
      end

      def create_channel(consumer_pool_size = 1)
        TestRabbitChannel.new(self)
      end
    end

    class TestRabbitChannel
      def initialize(connection)
        @connection = connection
      end

      def queue(name, options={})
        @connection.queue(name, [], options)
      end

      [:topic, :fanout, :direct].each do |type|
        define_method type do |name, options|
          TestRabbitExchange.new(name, options)
        end
      end

      def generate_consumer_tag
        "test-consumer-tag-#{rand(1000)}"
      end
    end

    class TestRabbitExchange
      attr_reader :name

      def initialize(name='test.exchange', options={})
        @name = name
      end
    end

    class TestQueue
      attr_reader :channel, :name, :options, :routing_key

      def initialize(channel, name, options)
        @name    = name
        @channel = channel
        @options = options
      end

      def bind(exchange, options)
        @routing_key = options[:routing_key]
      end

      def subscribe(*args)
        TestConsumer.new
      end

      def subscribe_with(*args)
        TestConsumer.new
      end
    end

    class TestConsumer
      def cancel
        TestConsumer.new
      end
    end

    class TestDeliveryInfo
      attr_reader :routing_key, :exchange

      def initialize(routing_key, exchange='TestExchange')
        @routing_key = routing_key
        @exchange    = exchange
      end

      def [](key)
        send(key)
      end
    end

    class TestMessageProperties
      attr_reader :reply_to, :message_id, :correlation_id

      def initialize(reply_to, message_id=nil, correlation_id=nil)
        @reply_to       = reply_to
        @message_id     = message_id
        @correlation_id = correlation_id
      end

      def [](key)
        send(key)
      end
    end

    class TestMessageHandler
      attr_reader :reply, :timeout_message, :error

      def call(reply)
        @reply = reply
      end

      def on_timeout(original_message=nil)
        @timeout_message = original_message
      end

      def on_error(error)
        @error = error
      end
    end
  end
end
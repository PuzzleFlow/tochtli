require_relative 'test_case'

module Tochtli
  # Ensure all queues are temporary
  BaseController.queue_durable     = false
  BaseController.queue_auto_delete = true

  module Test
    module IntegrationHelpers
      extend UnitTestSupport if defined?(::Test::Unit)

      def before_setup
        super
        @logger             = Tochtli.logger
        @logger.level       = Logger::DEBUG
        @client             = Tochtli::RabbitClient.new(nil, @logger)
        @connection         = @client.rabbit_connection
        @controller_manager = Tochtli::ControllerManager.instance
        @controller_manager.setup(connection: @connection, logger: @logger)
        @controller_manager.start(:all)

        # Reply support
        @mutex = Mutex.new
        @cv    = ConditionVariable.new
      end

      def after_teardown
        begin
          @controller_manager.stop if @controller_manager
        rescue Timeout::Error
          warn "Unable to stop controller manager: #{$!} [#{$!.class}]"
        end
        super
      end

      private

      def publish(message, options={})
        @reply               = nil
        timeout              = options.fetch(:timeout, 1.0)
        @reply_message_class = options[:expect]
        @reply_handler       = options[:reply_handler]

        if @reply_message_class || @reply_handler
          handler = @reply_handler || method(:synchronous_reply_handler)
          if handler.is_a?(Proc)
            @client.reply_queue.register_message_handler message, &handler
          else
            @client.reply_queue.register_message_handler message, handler, timeout
          end
        end

        @client.publish message

        if @reply_message_class && !@reply_handler
          synchronous_timeout_handler(message, timeout)
        end
      end

      def synchronous_reply_handler(reply)
        assert_kind_of @reply_message_class, reply, "Unexpected reply"
        @mutex.synchronize do
          @reply = reply
          @cv.signal
        end
      end

      def synchronous_timeout_handler(message, timeout)
        @mutex.synchronize { @cv.wait(@mutex, timeout) unless @reply }

        raise "Reply on #{message.class.name} timeout" unless @reply
        raise @reply.message if @reply.is_a?(Tochtli::ErrorMessage)

        @reply
      end
    end

    class Integration < Minitest::Test
      include IntegrationHelpers
    end
  end
end

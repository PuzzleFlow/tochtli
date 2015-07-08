module Tochtli
  class BaseClient
    attr_reader :rabbit_client, :rabbit_connection, :logger

    def initialize(rabbit_client_or_connection = nil, logger = nil)
      logger ||= Tochtli.logger
      case rabbit_client_or_connection
        when Tochtli::RabbitClient
          @rabbit_client = rabbit_client_or_connection
        when Tochtli::RabbitConnection
          @rabbit_client = Tochtli::RabbitClient.new(rabbit_client_or_connection, logger)
        when NilClass
          @rabbit_client = Tochtli::RabbitClient.new(nil, logger)
        else
          raise ArgumentError, "Tochtli::RabbitClient or Tochtli::RabbitConnection expected, got: #{rabbit_client_or_connection.class}"
      end
      @rabbit_connection = @rabbit_client.rabbit_connection
      @logger            = logger
    end

    def publish(*args)
      rabbit_client.publish(args)
    end

    class InternalServiceError < StandardError
      attr_reader :service_error

      def initialize(service_error, message)
        @service_error = service_error
        super message
      end
    end

    class AbstractMessageHandler
      def reconstruct_exception(error_message)
        if error_message.is_a?(Exception)
          error_message
        else
          if error_message.is_a?(ErrorMessage)
            error   = error_message.error
            message = error_message.message
            # Look for exception definition on client system
            exception_class = error.constantize rescue nil
            if exception_class < StandardError
              # Use known exception if found
              exception = exception_class.new(message)
            else
              # If the exception is not defined use generic InternalServiceError
              exception = InternalServiceError.new(error, message)
            end
          else
            exception = InternalServiceError.new(error_message.to_s)
          end
          exception.set_backtrace caller(0)
          exception
        end
      end
    end

    class MessageHandler < AbstractMessageHandler
      def initialize(external_handler)
        @external_handler = external_handler
      end

      def on_timeout(original_message)
        @external_handler.on_timeout
      end

      def on_error(error_message)
        error = reconstruct_exception(error_message)
        @external_handler.on_error error
      end
    end

    class SyncMessageHandler < AbstractMessageHandler
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
          @error = Timeout::Error.new(original_message ? "Unable to send message: #{original_message.inspect}" : "Service is not responding")
          @cv.signal
        end
      end

      def on_error(error_message)
        synchronize do
          @error = reconstruct_exception(error_message)
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
        error = self.error || InternalServiceError.new("Unknwon", "Unknown Error")
        raise error
      end
    end

  end
end


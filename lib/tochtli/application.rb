module Tochtli
  class Application
    def initialize
      @middleware_stack = MiddlewareStack.new
    end

    def use_default_middlewares
      @middleware_stack.use ErrorHandler
      @middleware_stack.use MessageSetup
      @middleware_stack.use MessageLogger
    end

    def to_app(app=nil)
      app ||= MessageHandler.new
      @middleware_stack.build(app)
    end

    def middlewares
      @middleware_stack
    end
  end

  class MiddlewareStack
    def initialize
      @middlewares = []
    end

    def use(middleware)
      @middlewares << middleware
    end

    def build(app)
      @middlewares.reverse.inject(app) { |a, e| e.new(a) }
    end
  end

  class Middleware
    def initialize(app)
      @app = app
    end
  end

  class ErrorHandler < Middleware
    def call(env)
      @app.call(env)
    rescue Exception => ex
      properties = env[:properties] || {}
      controller = env[:controller]
      logger     = env[:logger]

      logger.error "\n#{ex.class.name} (#{ex.message})"
      logger.error ex.backtrace.join("\n")
      if controller && properties[:reply_to]
        begin
          controller.reply ErrorMessage.new(error: ex.class.name, message: ex.message), properties[:reply_to], properties[:message_id]
        rescue
          logger.error "Unable to send error message: #{$!}"
          logger.error $!.backtrace.join("\n")
        end
      end
      false
    end
  end

  class MessageSetup < Middleware
    def call(env)
      controller_class  = env[:controller_class]
      delivery_info     = env[:delivery_info]
      payload           = env[:payload]
      properties        = env[:properties]
      rabbit_connection = env[:rabbit_connection]
      cache             = env[:cache]
      logger            = env[:logger]
      message_route     = controller_class.find_message_route(delivery_info.routing_key)

      if message_route
        env[:message]    = create_message(message_route.message_class, properties, payload)
        env[:controller] = controller_class.new(rabbit_connection, cache, logger)
        env[:action]     = message_route.action

        @app.call(env)

      else
        logger.error "\n\nMessage DROPPED by #{controller_class.name} at #{Time.now}"
        logger.error "\tProperties: #{properties.inspect}."
        logger.error "\tDelivery info: exchange: #{delivery_info[:exchange]}, routing_key: #{delivery_info[:routing_key]}."
        false
      end
    end

    def create_message(message_class, properties, payload)
      message = message_class.new(nil, properties)
      message.from_json(payload, false)
      raise InvalidMessageError.new(message.errors.full_messages.join(", "), message) if message.invalid?
      message
    end
  end

  class MessageLogger < Middleware
    def call(env)
      start_time       = Time.now
      message          = env[:message]
      controller_class = env[:controller_class]
      delivery_info    = env[:delivery_info]
      properties       = env[:properties]
      action           = env[:action]
      logger           = env[:logger]

      logger.debug "\n\nAMQP Message #{message.class.name} at #{start_time}"
      logger.debug "Processing by #{controller_class.name}##{action} [Thread: #{Thread.current.object_id}]"
      logger.debug "\tMessage: #{message.attributes.inspect}."
      logger.debug "\tProperties: #{properties.inspect}."
      logger.debug "\tDelivery info: exchange: #{delivery_info[:exchange]}, routing_key: #{delivery_info[:routing_key]}."

      result = @app.call(env)

      logger.debug "Message #{properties[:message_id]} processed in %.1fms." % [(Time.now - start_time) * 1000]

      result
    end
  end

  class MessageHandler
    def call(env)
      controller = env[:controller]

      controller.process_message(env)

      true
    end
  end

end
module Tochtli
  class BaseController
    extend Uber::InheritableAttribute

    inheritable_attr :routing_keys
    inheritable_attr :message_handlers
    inheritable_attr :work_pool_size

    self.work_pool_size = 1 # default work pool size per controller instance

    attr_reader :logger, :message, :delivery_info

    # Each controller can overwrite the queue name (default: controller.name.underscore)
    inheritable_attr :queue_name

    # Custom options for controller queue and exchange
    inheritable_attr :queue_durable
    self.queue_durable = true

    inheritable_attr :queue_auto_delete
    self.queue_auto_delete = false

    inheritable_attr :queue_exclusive
    self.queue_exclusive = false

    inheritable_attr :exchange_type
    self.exchange_type = :topic

    inheritable_attr :exchange_name # read from configuration by default

    inheritable_attr :exchange_durable
    self.exchange_durable = true

    # Message dispatcher created on start
    inheritable_attr :dispatcher

    protected

    # @private before setup callback
    inheritable_attr :before_setup_block

    class << self
      def inherited(controller)
        controller.routing_keys     = Set.new
        controller.message_handlers = Hash.new
        controller.queue_name       = controller.name.underscore.gsub('::', '/')
        ControllerManager.register(controller)
      end

      def bind(*routing_keys)
        self.routing_keys.merge(routing_keys)
      end

      def on(message_class, method_name=nil, opts={}, &block)
        if method_name.is_a?(Hash)
          opts        = method_name
          method_name = nil
        end
        method = method_name ? method_name : block
        raise ArgumentError, "Method name or block must be given" unless method

        raise ArgumentError, "Message class expected, got: #{message_class}" unless message_class < Tochtli::Message

        routing_key = opts[:routing_key] || message_class.routing_key
        raise "Topic not set for message: #{message_class}" unless routing_key

        self.message_handlers[routing_key] = MessageRoute.new(message_class, method)
      end

      def off(routing_key)
        self.message_handlers.delete(routing_key)
      end

      def before_setup(&block)
        self.before_setup_block = block
      end

      def setup(rabbit_connection, cache=nil, logger=nil)
        self.before_setup_block.call if self.before_setup_block
        self.dispatcher = Dispatcher.new(self, rabbit_connection, cache, logger || Tochtli.logger)
      end

      def start(queue_name=nil)
        self.dispatcher.start(queue_name || self.queue_name)
      end

      def set_up?
        !!self.dispatcher
      end

      def started?
        self.dispatcher && !self.dispatcher.queues.empty?
      end

      def stop(options={})
        self.dispatcher.shutdown(options) if started?
        self.dispatcher = nil
      end

      def restart(options={})
        connection = self.dispatcher.rabbit_connection
        logger     = self.dispatcher.logger
        cache      = self.dispatcher.cache

        stop(timeout: options.fetch(:timeout, 15))
        setup(connection, cache, logger)
        start
      end

      def find_message_route(routing_key)
        raise "Routing not set up" if self.message_handlers.empty?
        self.message_handlers[routing_key]
      end

      def create_queue(rabbit_connection, queue_name=nil)
        queue_name    = self.queue_name unless queue_name
        routing_keys  = self.routing_keys
        channel       = rabbit_connection.create_channel(self.work_pool_size)
        exchange_name = self.exchange_name || rabbit_connection.exchange_name
        exchange      = channel.send(self.exchange_type, exchange_name, durable: self.exchange_durable)
        queue         = channel.queue(queue_name,
                                      durable:     self.queue_durable,
                                      exclusive:   self.queue_exclusive,
                                      auto_delete: self.queue_auto_delete)

        routing_keys.each do |routing_key|
          queue.bind(exchange, routing_key: routing_key)
        end

        queue
      end
    end

    public

    def initialize(rabbit_connection, cache, logger)
      @rabbit_connection = rabbit_connection
      @cache             = cache
      @logger            = logger
    end

    def process_message(env)
      @env           = env
      @action        = env[:action]
      @message       = env[:message]
      @delivery_info = env[:delivery_info]

      if @action.is_a?(Proc)
        instance_eval(&@action)
      else
        send @action
      end

    ensure
      @env, @message, @delivery_info = nil
    end

    def reply(reply_message, reply_to=nil, message_id=nil)
      if @message
        reply_to   ||= @message.properties.reply_to
        message_id ||= @message.id
      end

      raise "The 'reply_to' queue name is not specified" unless reply_to

      logger.debug "\tSending  replay on #{message_id} to #{reply_to}: #{reply_message.inspect}."

      @rabbit_connection.publish(reply_to,
                                 reply_message,
                                 correlation_id: message_id)
    end

    class MessageRoute < Struct.new(:message_class, :action)
    end

    class Dispatcher
      attr_reader :controller_class, :rabbit_connection, :cache, :logger

      def initialize(controller_class, rabbit_connection, cache, logger)
        @controller_class  = controller_class
        @rabbit_connection = rabbit_connection
        @cache             = cache
        @logger            = logger
        @application       = Tochtli.application.to_app
        @queues            = {}
        @process_counter   = ProcessCounter.new
      end

      def start(queue_name)
        subscribe_queue(queue_name)
      end

      def process_message(delivery_info, properties, payload)
        register_process_start

        env = {
            delivery_info:     delivery_info,
            properties:        properties,
            payload:           payload,
            controller_class:  controller_class,
            rabbit_connection: rabbit_connection,
            cache:             cache,
            logger:            logger
        }

        @application.call(env)

      rescue Exception => ex
        logger.error "\nUNEXPECTED EXCEPTION: #{ex.class.name} (#{ex.message})"
        logger.error ex.backtrace.join("\n")
        false
      ensure
        register_process_end
      end

      def subscribe_queue(queue_name)
        queue    = controller_class.create_queue(@rabbit_connection, queue_name)
        consumer = queue.subscribe do |delivery_info, metadata, payload|
          process_message delivery_info, metadata, payload
        end

        @queues[queue_name] = {
            queue:    queue,
            consumer: consumer
        }
      end

      # Performs a graceful shutdown of dispatcher i.e. waits for all processes to end.
      # If timeout is reached, forces the shutdown. Useful with dynamic reconfiguration of work pool size. 
      def shutdown(options={})
        timeout = options[:timeout] || 15

        wait_for_processes timeout

        stop
      end

      def stop
        @queues.each_value { |qh| qh[:consumer].cancel }
        @consumer.cancel if @consumer
      rescue Bunny::ConnectionClosedError
        # ignore closed connection error
      end

      def queues
        @queues.map { |_, qh| qh[:queue] }
      end

      protected

      def register_process_start
        @process_counter.increment
      end

      def register_process_end
        @process_counter.decrement
      end

      def wait_for_processes(timeout)
        @process_counter.wait(timeout)
      end

      class ProcessCounter
        include MonitorMixin

        def initialize
          super
          @count = 0
          @cv    = new_cond
        end

        def increment
          synchronize do
            @count += 1
          end
        end

        def decrement
          synchronize do
            @count -= 1 if @count > 0
            @cv.signal if @count == 0
          end
        end

        def wait(timeout)
          synchronize do
            @cv.wait(timeout) unless @count == 0
          end
        end
      end
    end
  end
end
require 'hooks'

module Tochtli
  class BaseController
    extend Uber::InheritableAttribute
    include Hooks
    include Hooks::InstanceHooks

    inheritable_attr :routing_keys
    inheritable_attr :message_handlers
    inheritable_attr :work_pool_size, clone: false

    self.work_pool_size = 1 # default work pool size per controller instance

    attr_reader :logger, :env, :message, :delivery_info

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

    define_hooks :before_setup, :after_setup,
                 :before_start, :after_start,
                 :before_stop, :after_stop,
                 :before_restart, :after_restart

    class << self
      def inherited(controller)
        controller.routing_keys     = Set.new
        controller.message_handlers = Array.new
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

        self.message_handlers << MessageRoute.new(message_class, method, routing_key)
      end

      def off(routing_key)
        self.message_handlers.delete_if {|route| route.routing_key == routing_key }
      end


      def setup(rabbit_connection, cache=nil, logger=nil)
        run_hook :before_setup, rabbit_connection
        self.dispatcher = Dispatcher.new(self, rabbit_connection, cache, logger || Tochtli.logger)
        run_hook :after_setup, rabbit_connection
      end

      def start(queue_name=nil, routing_keys=nil, initial_env={})
        run_hook :before_start, queue_name, initial_env
        self.dispatcher.start(queue_name || self.queue_name, routing_keys || self.routing_keys, initial_env)
        run_hook :after_start, queue_name, initial_env
      end

      def set_up?
        !!self.dispatcher
      end

      def started?(queue_name=nil)
        self.dispatcher && self.dispatcher.started?(queue_name)
      end

      def stop(options={})
        if started?
          queues = self.dispatcher.queues
          run_hook :before_stop, queues
        end

        if self.dispatcher
          self.dispatcher.shutdown(options)
          self.dispatcher = nil

          run_hook :after_stop, queues

          true
        else
          false
        end
      end

      def restart(options={})
        if started?
          queues = self.dispatcher.queues
          run_hook :before_restart, queues
          self.dispatcher.restart options
          run_hook :after_restart, queues
        end
      end

      def find_message_route(routing_key)
        raise "Routing not set up" if self.message_handlers.empty?
        self.message_handlers.find {|handler| handler.pattern =~ routing_key }
      end

      def create_queue(rabbit_connection, queue_name=nil, routing_keys=nil)
        queue_name    = self.queue_name unless queue_name
        routing_keys  = self.routing_keys unless routing_keys
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

      logger.debug "\tSending  reply on #{message_id} to #{reply_to}: #{reply_message.inspect}."

      @rabbit_connection.publish(reply_to,
                                 reply_message,
                                 correlation_id: message_id)
    end

    def rabbit_connection
      self.class.dispatcher.rabbit_connection if self.class.set_up?
    end

    class MessageRoute < Struct.new(:message_class, :action, :routing_key, :pattern)
      def initialize(message_class, action, routing_key)
        super message_class, action, routing_key, KeyPattern.new(routing_key)
      end
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
        @initial_env       = nil
      end

      def start(queue_name, routing_keys, initial_env={})
        subscribe_queue(queue_name, routing_keys, initial_env)
      end

      def restart(options={})
        queues = @queues.dup

        shutdown options

        queues.each do |queue_name, queue_opts|
          start queue_name, queue_opts[:initial_env]
        end
      end

      def process_message(delivery_info, properties, payload, initial_env)
        register_process_start

        env = initial_env.merge(
            delivery_info:     delivery_info,
            properties:        properties,
            payload:           payload,
            controller_class:  controller_class,
            rabbit_connection: rabbit_connection,
            cache:             cache,
            logger:            logger
        )

        @application.call(env)

      rescue StandardError => ex
        logger.error "\nUNEXPECTED EXCEPTION: #{ex.class.name} (#{ex.message})"
        logger.error ex.backtrace.join("\n")
        false
      ensure
        register_process_end
      end

      def subscribe_queue(queue_name, routing_keys, initial_env={})
        queue    = controller_class.create_queue(@rabbit_connection, queue_name, routing_keys)
        consumer = queue.subscribe do |delivery_info, metadata, payload|
          process_message delivery_info, metadata, payload, initial_env
        end

        @queues[queue_name] = {
            queue:       queue,
            consumer:    consumer,
            initial_env: initial_env
        }
      end

      # Performs a graceful shutdown of dispatcher i.e. waits for all processes to end.
      # If timeout is reached, forces the shutdown. Useful with dynamic reconfiguration of work pool size.
      def shutdown(options={})
        wait_for_processes options.fetch(:timeout, 15)
        stop
      end

      def stop(queues=nil)
        @queues.each_value { |queue_opts| queue_opts[:consumer].cancel }
      rescue Bunny::ConnectionClosedError
        # ignore closed connection error
      ensure
        @queues = {}
      end

      def started?(queue_name=nil)
        if queue_name
          @queues.has_key?(queue_name)
        else
          !@queues.empty?
        end
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

    class KeyPattern
      ASTERIX_EXP = '[a-zA-Z0-9]+'
      HASH_EXP = '[a-zA-Z0-9\.]*'

      def initialize(pattern)
        @str = pattern
        @simple = !pattern.include?('*') && !pattern.include?('#')
        if @simple
          @pattern = pattern
        else
          @pattern = Regexp.new('^' + pattern.gsub('.', '\\.').
              gsub('*', ASTERIX_EXP).gsub(/(\\\.)?#(\\\.)?/, HASH_EXP) + '$')
        end
      end

      def =~(key)
        if @simple
          @pattern == key
        else
          @pattern =~ key
        end
      end

      def !~(key)
        !(self =~ key)
      end

      def to_s
        @str
      end
    end
  end
end

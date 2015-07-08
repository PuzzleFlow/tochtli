module Tochtli
  class BaseController
    extend Uber::InheritableAttribute

    inheritable_attr :routing_keys
    inheritable_attr :static_message_handlers
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
        controller.routing_keys            = Set.new
        controller.static_message_handlers = Hash.new
        controller.queue_name              = controller.name.underscore.gsub('::', '/')
        ControllerManager.register(controller)
      end

      def subscribe(*routing_keys)
        self.routing_keys.merge(routing_keys)
      end

      def on(routing_key, method_name, message_class=nil)
        message_class ||= Tochtli::MessageMap.instance.for(routing_key)
        raise "Message class not found for the topic: #{routing_key}." unless message_class
        self.static_message_handlers[routing_key] = MessageRoute.new(message_class, method_name)
      end

      def unbind(routing_key)
        self.static_message_handlers.delete(routing_key)
      end

      def before_setup(&block)
        self.before_setup_block = block
      end

      def setup(rabbit_connection, cache=nil, logger=nil)
        self.before_setup_block.call if self.before_setup_block
        setup_routing
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
        clear_routing
      end

      def restart(options={})
        connection = self.dispatcher.rabbit_connection
        logger = self.dispatcher.logger
        cache = self.dispatcher.cache

        stop(timeout: options.fetch(:timeout, 15))
        setup(connection, cache, logger)
        start
      end

      def setup_routing
        clear_routing
        setup_static_routing
        setup_automatic_routing
      end

      def clear_routing
        @routing = {}
      end

      def setup_static_routing
        @routing.merge!(self.static_message_handlers)
      end

      def setup_automatic_routing
        if self.routing_keys.size == 1 && self.routing_keys.first =~ /^([a-z\.]+\.)\*$/
          routing_key_prefix = $1
          self.public_instance_methods(false).each do |method_name|
            routing_key   = routing_key_prefix + method_name.to_s
            message_class = Tochtli::MessageMap.instance.for(routing_key)
            raise "Topic '#{routing_key}' is not bound to any message. Unable to setup automatic routing for #{self.class}." unless message_class
            @routing[routing_key] = MessageRoute.new(message_class, method_name)
          end
        end
      end

      def find_message_route(routing_key)
        raise "Routing not set up" unless @routing
        @routing[routing_key]
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

      send @action

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
        @mutex             = Mutex.new
        @current_processes = 0
      end

      def start(queue_name)
        subscribe_queue(queue_name)
      end

      def process_message(delivery_info, properties, payload)
        @mutex.synchronize { @current_processes += 1}
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
        @mutex.synchronize { @current_processes -= 1}
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
        interval = options[:interval] || 0.5

        (timeout/interval).to_i.times do
          break if @current_processes == 0
          sleep(interval)
        end

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
    end
  end
end
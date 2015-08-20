require 'singleton'

module Tochtli
  class ControllerManager
    include Singleton

    attr_reader :rabbit_connection, :cache, :logger

    def initialize
      @controller_classes = Set.new
    end

    def register(controller_class)
      raise ArgumentError, "Controller expected, got: #{controller_class}" unless controller_class.is_a?(Class) && controller_class < Tochtli::BaseController
      @controller_classes << controller_class
    end

    def setup(options={})
      @logger            = options.fetch(:logger, Tochtli.logger)
      @cache             = options.fetch(:cache, Tochtli.cache)
      @rabbit_connection = options[:connection]

      unless @rabbit_connection
        @rabbit_connection = RabbitConnection.open(options[:config])
      end
    end

    def start(*controllers)
      options       = controllers.extract_options!
      setup_options = options.except!(:logger, :cache, :connection)
      queue_name    = options.delete(:queue_name)
      routing_keys  = options.delete(:routing_keys)
      initial_env   = options.delete(:env) || {}

      setup(setup_options) unless set_up?

      if controllers.empty? || controllers.include?(:all)
        controllers = @controller_classes
      end

      controllers.each do |controller_class|
        raise ArgumentError, "Controller expected, got: #{controller_class.inspect}" unless controller_class.is_a?(Class) && controller_class < Tochtli::BaseController
        unless controller_class.started?(queue_name)
          controller_class.setup(@rabbit_connection, @cache, @logger) unless controller_class.set_up?
          controller_class.start queue_name, routing_keys, initial_env
          @logger.info "[#{Time.now} AMQP] Started #{controller_class}" if @logger
        end
      end
    end

    def stop
      @controller_classes.each do |controller_class|
        if controller_class.stop
          @logger.info "[#{Time.now} AMQP] Stopped #{controller_class}" if @logger
        end
      end
      @rabbit_connection = nil
    end

    def restart(options={})
      options[:rabbit_connection] ||= @rabbit_connection
      options[:logger]            ||= @logger
      options[:cache]             ||= @cache

      setup options
      restart_active_controllers
    end

    def set_up?
      !@rabbit_connection.nil?
    end

    def running?
      @rabbit_connection && @rabbit_connection.open?
    end

    protected

    def restart_active_controllers
      @controller_classes.each do |controller_class|
        if controller_class.started?
          @logger.info "Restarting #{controller_class}..." if @logger
          controller_class.restart
        end
      end
    end

    class << self
      def method_missing(method, *args)
        if instance.respond_to?(method)
          instance.send(method, *args)
        else
          super
        end
      end
    end
  end
end
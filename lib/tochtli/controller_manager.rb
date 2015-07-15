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

    def setup(options)
      @logger            = options.fetch(:logger, Tochtli.logger)
      @cache             = options.fetch(:cache, Tochtli.cache)
      @rabbit_connection = options[:connection]

      unless @rabbit_connection
        @rabbit_connection = RabbitConnection.open(options[:config])
      end
    end

    #def start(rabbit_or_config=nil, logger=nil)
    def start(*controllers)
      options = controllers.extract_options!
      setup(options) unless @rabbit_connection

      if controllers.empty? || controllers.include?(:all)
        controllers = @controller_classes
      end

      controllers.each do |controller_class|
        raise ArgumentError, "Controller expected, got: #{controller_class.inspect}" unless controller_class.is_a?(Class) && controller_class < Tochtli::BaseController
        unless controller_class.started?
          @logger.info "Starting #{controller_class}..." if @logger
          controller_class.setup(@rabbit_connection, @cache, @logger)
          controller_class.start
        end
      end
    end

    def stop
      @controller_classes.each do |controller_class|
        if controller_class.started?
          @logger.info "Stopping #{controller_class}..." if @logger
          controller_class.stop
        end
      end
      @rabbit_connection = nil
    end

    def restart(options={})
      active_controllers = @controller_classes.select(&:started?)
      stop
      start *active_controllers, options
    end

    def running?
      @rabbit_connection && @rabbit_connection.open?
    end

    class << self
      def method_missing(method, *args)
        if [:register, :setup, :start, :stop, :restart, :running?, :logger, :rabbit_connection, :cache].include?(method)
          instance.send(method, *args)
        else
          super
        end
      end
    end
  end
end
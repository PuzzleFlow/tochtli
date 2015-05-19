module ServiceBase
	class ControllerManager
		include Singleton

		attr_reader :rabbit_connection, :cache, :logger

		def initialize
			@controller_classes = []
			@dispatchers = []
		end

		def register(controller_class)
			@controller_classes << controller_class
		end

		def start(rabbit_or_config=nil, logger=nil)
			@logger = logger || ServiceBase.logger
			@cache = ServiceBase::ServiceCache.store

			if rabbit_or_config.is_a?(RabbitConnection)
				@rabbit_connection = rabbit_or_config
			else
				@rabbit_config_name = rabbit_or_config
				@rabbit_connection = RabbitConnection.open(@rabbit_config_name)
			end

			@controller_classes.each do |controller_class|
				@logger.info "Starting #{controller_class}..." if @logger
				controller_class.setup
				dispatcher = BaseController::Dispatcher.new(controller_class, @rabbit_connection, @cache, @logger)
				dispatcher.start
				@dispatchers << dispatcher
			end
		end

		def stop
			@dispatchers.each {|dispatcher| dispatcher.stop rescue nil }
			@dispatchers.clear

			@controller_classes.each do |controller_class|
				controller_class.stop rescue nil
			end

			RabbitConnection.close(@rabbit_config_name) if @rabbit_config_name
		end

		def running?
			@rabbit_connection && @rabbit_connection.open?
		end

		def dispatcher_for(controller_class)
			@dispatchers.find {|dispatcher| dispatcher.controller_class == controller_class }
		end

		class << self
			delegate :register, :start, :stop, :running?, :logger, :rabbit_connection, :cache, :dispatcher_for, :to => :instance
		end
	end
end
module ServiceBase
	class ControllerManager
		include Singleton

		attr_reader :rabbit_connection, :cache, :logger

		# Settings for tests
		cattr_accessor :queue_name_prefix
		self.queue_name_prefix = ''

		cattr_accessor :queue_durable
		self.queue_durable = true

		cattr_accessor :queue_auto_delete
		self.queue_auto_delete = false

		def initialize
			@controller_classes = []
			@controllers = []
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
				controller = controller_class.new(@rabbit_connection, @cache, @logger)
				controller.start
				@controllers << controller
			end
		end

		def stop
			@controllers.each {|controller| controller.stop rescue nil }
			@controllers.clear

			RabbitConnection.close(@rabbit_config_name) if @rabbit_config_name
		end

		def running?
			@rabbit_connection && @rabbit_connection.open?
		end

		def controller_queue_name(controller_class)
			self.class.queue_name_prefix + controller_class.name.underscore
		end

		def create_controller_queue(controller_class, queue_name=nil)
			queue_name ||= controller_queue_name(controller_class)
			routing_keys = controller_class.routing_keys
			@rabbit_connection.queue(queue_name, routing_keys,
															 durable: self.class.queue_durable,
															 auto_delete: self.class.queue_auto_delete)
		end

		class << self
			delegate :register, :start, :stop, :running?, :logger,
			         :create_controller_queue, :controller_queue_name, :to => :instance
		end
	end
end
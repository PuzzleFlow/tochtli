module ServiceBase
	class ControllerManager
		include Singleton

		attr_reader :rabbit_connection, :cache, :configuration_store, :logger

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
			@logger = logger
			@cache = ServiceBase::ServiceCache.create
			@configuration_store = ServiceBase::Configuration::ActiveRecordStore.new

			@rabbit_connection = rabbit_or_config.is_a?(RabbitConnection) ? rabbit_or_config : RabbitConnection.new(rabbit_or_config)
			@rabbit_connection.connect

			@controller_classes.each do |controller_class|
				@logger.info "Starting #{controller_class}..." if @logger
				controller = controller_class.new(@rabbit_connection, @cache, @configuration_store, @logger)
				controller.start
				@controllers << controller
			end
		end

		def stop
			@rabbit_connection.disconnect if @rabbit_connection.open?
		end

		def create_controller_queue(controller_class)
			queue_name = self.class.queue_name_prefix + controller_class.name.underscore
			routing_keys = controller_class.routing_keys
			@rabbit_connection.queue(queue_name, routing_keys,
															 durable: self.class.queue_durable,
															 auto_delete: self.class.queue_auto_delete)
		end

		class << self
			delegate :register, :start, :create_controller_queue, :logger, :to => :instance
		end
	end
end
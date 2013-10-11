module ServiceBase
	class ControllerManager
		include Singleton

		attr_reader :rabbit_connection, :cache

		def initialize
			@controller_classes = []
			@controllers = []
		end

		def register(controller_class)
			@controller_classes << controller_class
		end

		def start(rabbit_config=nil)
			@cache = ActiveSupport::Cache::MemoryStore.new

			@rabbit_connection = RabbitConnection.new(rabbit_config)
			@rabbit_connection.connect

			@controller_classes.each do |controller_class|
				controller = controller_class.new(@rabbit_connection, @cache)
				controller.start
				@controllers << controller
			end
		end

		def stop
			@rabbit_connection.disconnect if @rabbit_connection.open?
		end

		class << self
			delegate :register, :start, :to => :instance
		end
	end
end
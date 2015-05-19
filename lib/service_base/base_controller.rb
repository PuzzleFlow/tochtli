module ServiceBase
	class BaseController
		class_attribute :routing_keys,
										:static_message_handlers,
										:work_pool_size

		self.work_pool_size = 1 # default work pool size per controller instance

		attr_reader :logger, :message

		# Each controller can overwrite the queue name (default: controller.name.underscore)
		class_attribute :queue_name

		# Custom options for controller queue and exchange
		class_attribute :queue_durable
		self.queue_durable = true

		class_attribute :queue_auto_delete
		self.queue_auto_delete = false

		class_attribute :queue_exclusive
		self.queue_exclusive = false

		class_attribute :exchange_type
		self.exchange_type = :topic

		class_attribute :exchange_name # read from configuration by default

		class_attribute :exchange_durable
		self.exchange_durable = true

	protected

		# @private before setup callback
		class_attribute :before_setup_block

		class << self
			def inherited(controller)
				controller.routing_keys            = Set.new
				controller.static_message_handlers = Hash.new
				controller.queue_name              = controller.name.underscore
				ControllerManager.register(controller)
			end

			def subscribe(*routing_keys)
				self.routing_keys.merge(routing_keys)
			end

			def on(routing_key, method_name, message_class=nil)
				message_class ||= ServiceBase::MessageMap.instance.for(routing_key)
				raise "Message class not found for the topic: #{routing_key}." unless message_class
				self.static_message_handlers[routing_key] = MessageHandler.new(message_class, method_name)
			end

			def unbind(routing_key)
				self.static_message_handlers.delete(routing_key)
			end

			def before_setup(name=nil, &block)
				self.before_setup_block = name ? self.method(name) : block
			end

			def setup
				self.before_setup_block.call if self.before_setup_block
				setup_routing
			end

			def stop
				clear_routing
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
						routing_key = routing_key_prefix + method_name.to_s
						message_class = ServiceBase::MessageMap.instance.for(routing_key)
						raise "Topic '#{routing_key}' is not bound to any message. Unable to setup automatic routing for #{self.class}." unless message_class
						@routing[routing_key] = MessageHandler.new(message_class, method_name)
					end
				end
			end

			def fetch_message_handler(routing_key)
				raise "Routing not set up" unless @routing
				@routing[routing_key]
			end

			def create_queue(rabbit_connection, queue_name=nil)
				queue_name   = self.queue_name unless queue_name
				routing_keys = self.routing_keys
				channel      = rabbit_connection.create_channel(self.work_pool_size)
				exchange_name = self.exchange_name || rabbit_connection.exchange_name
				exchange     = channel.send(self.exchange_type, exchange_name, durable: self.exchange_durable)
				queue        = channel.queue(queue_name,
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
			@cache = cache
			@logger = logger
		end

		def setup_message(message, delivery_info)
			@message, @delivery_info = message, delivery_info
		end

		def reply(reply_message, reply_to=nil, message_id=nil)
			if @message
				reply_to ||= @message.properties.reply_to
				message_id ||= @message.id
			end

			raise "The 'reply_to' queue name is not specified" unless reply_to

			logger.debug "\tSending  replay on #{message_id} to #{reply_to}: #{reply_message.inspect}."

			@rabbit_connection.publish(reply_to,
																 reply_message,
																 correlation_id: message_id)
		end

		class Dispatcher
			attr_reader :controller_class, :rabbit_connection, :cache, :logger, :queue

			def initialize(controller_class, rabbit_connection, cache, logger)
				@controller_class  = controller_class
				@rabbit_connection = rabbit_connection
				@cache             = cache
				@logger            = logger
			end

			def start
				create_queue
				subscribe_queue
			end

			def process_message(delivery_info, properties, payload)
				if (message_handler = @controller_class.fetch_message_handler(delivery_info.routing_key))
					controller_instance = @controller_class.new(@rabbit_connection, @cache, @logger)
					begin
						message = message_handler.create_message(delivery_info, properties, payload)

						start_time = Time.now
						logger.debug "\n\nAMQP Message #{message.class.name} at #{start_time}"
						logger.debug "Processing by #{@controller_class.name} [Thread: #{Thread.current.object_id}]"
						logger.debug "\tMessage: #{message.attributes.inspect}."
						logger.debug "\tProperties: #{properties.inspect}."
						logger.debug "\tDelivery info: exchange: #{delivery_info[:exchange]}, routing_key: #{delivery_info[:routing_key]}."

						message_handler.call(controller_instance, message, delivery_info)

						logger.debug "Message #{properties[:message_id]} processed in %.1fms." % [(Time.now - start_time) * 1000]
						true
					rescue Bunny::Exception
						# Possible connection error - the controller manager would try to restart connection
						on_connection_lost $!
						false
					end
				else
					logger.error "\n\nMessage DROPPED by #{@controller_class.name} at #{Time.now}"
					logger.error "\tProperties: #{properties.inspect}."
					logger.error "\tDelivery info: exchange: #{delivery_info[:exchange]}, routing_key: #{delivery_info[:routing_key]}."

					false
				end
			rescue Exception => ex
				logger.error "\n#{ex.class.name} (#{ex.message})"
				logger.error ex.backtrace.join("\n")
				if properties[:reply_to]
					begin
						controller_instance.reply ErrorMessage.new(error: ex.class.name, message: ex.message), properties[:reply_to], properties[:message_id]
					rescue
						logger.error "Unable to send error message: #{$!}"
						logger.error $!.backtrace.join("\n")
					end
				end
				false
			end

			def on_connection_lost(exception)
				logger.error "\nConnection lost: #{exception.class.name} (#{exception.message})"
				logger.error exception.backtrace.join("\n")

				ServiceBase::ControllerManager.stop
			end

			def create_queue
				@queue = controller_class.create_queue(@rabbit_connection)
			end

			def subscribe_queue
				@consumer = @queue.subscribe do |delivery_info, metadata, payload|
					process_message delivery_info, metadata, payload
				end
			end

			def stop
				@consumer.cancel if @consumer
			end
		end

		class MessageHandler
			def initialize(message_class, method_name)
				@message_class = message_class
				@method_name = method_name
			end

			def create_message(delivery_info, properties, payload)
				message = @message_class.new(nil, properties)
				message.from_json(payload, false)
				raise InvalidMessageError.new(message.errors.full_messages.join(", "), message) if message.invalid?
				message
			end

			def call(controller_instance, message, delivery_info)
				controller_instance.setup_message(message, delivery_info)
				controller_instance.send(@method_name)
			end
		end

	end
end
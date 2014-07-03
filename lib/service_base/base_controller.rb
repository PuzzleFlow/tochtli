module ServiceBase
	class BaseController
		class_attribute :routing_keys,
										:static_message_handlers

		attr_reader :logger, :message

		def self.inherited(controller)
			controller.routing_keys = Set.new
			controller.static_message_handlers = Hash.new
			ControllerManager.register(controller)
		end

		def self.subscribe(*routing_keys)
			self.routing_keys.merge(routing_keys)
		end

		def self.on(routing_key, method_name, message_class=nil)
			message_class ||= ServiceBase::MessageMap.instance.for(routing_key)
			raise "Message class not found for the topic: #{routing_key}." unless message_class
			self.static_message_handlers[routing_key] = MessageHandler.new(routing_key, message_class, method_name)
		end

		def initialize(rabbit_connection, cache, configuration_store, logger)
			@rabbit_connection = rabbit_connection
			@cache = cache
			@configuration_store = configuration_store
			@logger = logger

			setup_routing
		end

		def start
			create_queue
			subscribe_queue
		end

		def process_message(delivery_info, properties, payload)
			if (message_handler = fetch_message_handler(delivery_info.routing_key))
				@message = message_handler.create_message(delivery_info, properties, payload)
				@delivery_info = delivery_info

				logger.debug "\n\nAMQP Message #{@message.class.name} at #{Time.now}"
				logger.debug "Processing by #{self.class.name} [Thread: #{Thread.current.object_id}]"
				logger.debug "\tMessage: #{@message.attributes.inspect}."
				logger.debug "\tProperties: #{properties.inspect}."
				logger.debug "\tDelivery info: exchange: #{delivery_info[:exchange]}, routing_key: #{delivery_info[:routing_key]}."

				begin
					message_handler.call(self)
					true
				rescue Bunny::Exception
					# Possible connection error - the controller manager would try to restart connection
					on_connection_lost $!
					false
				rescue Exception => ex
					logger.error "\n#{ex.class.name} (#{ex.message})"
					logger.error ex.backtrace.join("\n")
					reply ErrorMessage.new(error: ex.class.name.demodulize, message: ex.message) if @message.properties.reply_to
					false
				end
			else
				false
			end
		rescue Exception => ex
			logger.error "\n#{ex.class.name} (#{ex.message})"
			logger.error ex.backtrace.join("\n")
		ensure
			cleanup
		end

		def cleanup
			@message = nil
			@delivery_info = nil
		end

		protected

		def setup_routing
			clear_routing
			setup_static_routing
			setup_automatic_routing
		end

		def clear_routing
			@routing = {}
		end

		def setup_static_routing
			@routing.merge!(self.class.static_message_handlers)
		end

		def setup_automatic_routing
			if self.routing_keys.size == 1 && self.routing_keys.first =~ /^([a-z\.]+\.)\*$/
				routing_key_prefix = $1
				self.class.public_instance_methods(false).each do |method_name|
					routing_key = routing_key_prefix + method_name.to_s
					message_class = ServiceBase::MessageMap.instance.for(routing_key)
					raise "Topic '#{routing_key}' is not bound to any message. Unable to setup automatic routing for #{self.class}." unless message_class
					@routing[routing_key] = MessageHandler.new(routing_key, message_class, method_name)
				end
			end
		end

		def fetch_message_handler(routing_key)
			@routing[routing_key]
		end

		def queue_name
			ControllerManager.controller_queue_name(self)
		end

		def create_queue
			@queue = ControllerManager.create_controller_queue(self.class)
		end

		def subscribe_queue
			@queue.subscribe do |delivery_info, metadata, payload|
				process_message delivery_info, metadata, payload
			end
		end

		def reply(reply_message)
			raise "The 'reply_to' queue name is not specified" unless @message.properties.reply_to
			@rabbit_connection.publish(@message.properties.reply_to,
																 reply_message,
																 correlation_id: @message.id)
		end

		def on_connection_lost(exception)
			logger.error "\nConnection lost: #{exception.class.name} (#{exception.message})"
			logger.error exception.backtrace.join("\n")

			ServiceBase::ControllerManager.stop
		end

		class MessageHandler
			def initialize(topic, message_class, method_name)
				@topic = topic
				@message_class = message_class
				@method_name = method_name
			end

			def create_message(delivery_info, properties, payload)
				message = @message_class.new(nil, properties)
				message.from_json(payload, false)
				raise InvalidMessageError.new(message.errors.full_messages.join(", "), message) if message.invalid?
				message
			end

			def call(controller_instance)
				controller_instance.send @method_name
			end
		end

		class InvalidMessageError < StandardError
			def initialize(message, service_message)
				super(message)
				@service_message = service_message
			end
		end
	end
end
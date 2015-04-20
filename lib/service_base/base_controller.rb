module ServiceBase
	class BaseController
		include ActiveSupport::Callbacks

		CALLBACKS = [:start, :setup]
		CALLBACK_FILTER_TYPES = [:before, :after, :around]

		class_attribute :routing_keys,
										:static_message_handlers

		attr_reader :logger, :message

		define_callbacks *CALLBACKS
		CALLBACK_FILTER_TYPES.each do |filter_type|
			CALLBACKS.each do |callback|
				class_eval <<-RUBY
					def self.#{filter_type}_#{callback}(*args, &block)
						set_callback :#{callback}, :#{filter_type}, *args, &block
					end
				RUBY
			end
		end

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
			self.static_message_handlers[routing_key] = MessageHandler.new(message_class, method_name)
		end

		def self.unbind(routing_key)
			self.static_message_handlers.delete(routing_key)
		end

		def initialize(rabbit_connection, cache, configuration_store, logger)
			@rabbit_connection = rabbit_connection
			@cache = cache
			@configuration_store = configuration_store
			@logger = logger

			setup
		end

		def start
			run_callbacks :start do
				create_queue
				subscribe_queue
			end
		end

		def setup
			run_callbacks :setup do
				setup_routing
			end
		end

		def process_message(delivery_info, properties, payload)
			if (message_handler = fetch_message_handler(delivery_info.routing_key))
				begin
					@message = message_handler.create_message(delivery_info, properties, payload)
					@delivery_info = delivery_info

					start_time = Time.now
					logger.debug "\n\nAMQP Message #{@message.class.name} at #{start_time}"
					logger.debug "Processing by #{self.class.name} [Thread: #{Thread.current.object_id}]"
					logger.debug "\tMessage: #{@message.attributes.inspect}."
					logger.debug "\tProperties: #{properties.inspect}."
					logger.debug "\tDelivery info: exchange: #{delivery_info[:exchange]}, routing_key: #{delivery_info[:routing_key]}."

					message_handler.call(self)

					logger.debug "Message #{properties[:message_id]} processed in %.1fms." % [(Time.now - start_time) * 1000]
					true
				rescue Bunny::Exception
					# Possible connection error - the controller manager would try to restart connection
					on_connection_lost $!
					false
				end
			else
				logger.error "\n\nMessage DROPPED by #{self.class.name} at #{Time.now}"
				logger.error "\tProperties: #{properties.inspect}."
				logger.error "\tDelivery info: exchange: #{delivery_info[:exchange]}, routing_key: #{delivery_info[:routing_key]}."

				false
			end
		rescue Exception => ex
			logger.error "\n#{ex.class.name} (#{ex.message})"
			logger.error ex.backtrace.join("\n")
			if properties[:reply_to]
				begin
					reply ErrorMessage.new(error: ex.class.name, message: ex.message), properties[:reply_to], properties[:message_id]
				rescue
					logger.error "Unable to send error message: #{$!}"
					logger.error $!.backtrace.join("\n")
				end
			end
			false
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
					@routing[routing_key] = MessageHandler.new(message_class, method_name)
				end
			end
		end

		def fetch_message_handler(routing_key)
			@routing[routing_key]
		end

		def queue_name
			ControllerManager.controller_queue_name(self.class)
		end

		def create_queue
			@queue = ControllerManager.create_controller_queue(self.class, queue_name)
		end

		def subscribe_queue
			@queue.subscribe do |delivery_info, metadata, payload|
				process_message delivery_info, metadata, payload
			end
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

		def on_connection_lost(exception)
			logger.error "\nConnection lost: #{exception.class.name} (#{exception.message})"
			logger.error exception.backtrace.join("\n")

			ServiceBase::ControllerManager.stop
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

			def call(controller_instance)
				controller_instance.send @method_name
			end
		end

	end
end
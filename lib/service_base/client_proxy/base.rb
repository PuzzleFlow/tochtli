module ServiceBase
	module ClientProxy
		class Base
			attr_reader :client, :controller

			def initialize(client, controller)
				@client = client
				@controller = controller
			end

			delegate :client_id, to: :@client

			protected

			def self.delegate_command(*commands)
				commands.each do |command|
					define_command_delegation command
				end
			end

			def self.define_command_delegation(command)
				class_eval <<-RUBY
				def #{command}(*args, &block)
					original_arity = -@client.method(:#{command}).arity
					options = args[original_arity-2] || {} # skip handler
					args = args[0..original_arity-3] # skip handler and options
					dispatch_command(:#{command}, *args, options, &block)
				end
				RUBY
			end
		end

		class ReplyMessageHandler
			def initialize(client_proxy, callback)
				@client_proxy = client_proxy
				@client = client_proxy.client
				@controller = client_proxy.controller
				@callback = callback
			end

			def on_timeout
				exception = TimeoutError.new("#{@client.service_friendly_name} is not responding")
				exception.set_backtrace caller(0)
				handle_exception exception
			end

			def on_error(error_or_exception, message=nil)
				if error_or_exception.is_a?(Exception)
					exception = error_or_exception
				else
					# Look for exception definition on client system
					exception_class = error_or_exception.constantize rescue nil
					if exception_class < StandardError
						# Use known exception if found
						exception = exception_class.new(message)
					else
						# If the exception is not defined use generic InternalServiceError
						exception = InternalServiceError.new(error_or_exception, "#{error_or_exception} from #{@client.service_friendly_name}: #{message}")
					end
					exception.set_backtrace caller(0)
				end
				handle_exception exception
			end
		end

		class InternalServiceError < StandardError
			attr_reader :service_error

			def initialize(service_error, message)
				@service_error = service_error
				super message
			end
		end
	end
end
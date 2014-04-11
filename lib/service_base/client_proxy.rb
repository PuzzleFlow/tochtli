module ServiceBase
	class ClientProxy
		def initialize(client, controller)
			@client = client
			@controller = controller
		end

		delegate :client_id, to: :@client
		cattr_accessor :custom_exceptions do
			{}
		end

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
					final_command = block_given? && options.fetch(:final, true)
					reply_handler = ReplyMessageHandler.new(@client, @controller, block, final_command)
					@client.send(:#{command}, *args, reply_handler, options)
					throw :async if final_command
				end
			RUBY
		end

		def self.handle_exception(exception, method_name)
			custom_exceptions[exception] = method_name
		end
	end

	class ReplyMessageHandler
		def initialize(client, controller, callback, final_command)
			@client = client
			@controller = controller
			@callback = callback
			@final_command = final_command
		end

		def call(reply)
			@callback.call(reply) if @callback
			if @final_command
				@controller.render unless @controller.performed?
				EM.next_tick { @controller.env['async.callback'].call @controller.to_a }
			end
		rescue Exception
			handle_exception $!
		end

		def on_timeout
			exception = TimeoutError.new("#{@client.service_friendly_name} is not responding")
			exception.set_backtrace caller(0)
			handle_exception exception
		end

		def on_error(error_or_exception, message)
			if error_or_exception.is_a?(Exception)
				exception = error_or_exception
			else
				exception = InternalServiceError.new("#{error_or_exception} from #{@client.service_friendly_name}: #{message}")
				exception.set_backtrace caller(0)
			end
			handle_exception exception
		end

		private

		def handled_response(exception)
			exception_method = ClientProxy.custom_exceptions[exception.to_s]
			custom_response = nil

			custom_response = @controller.uas_proxy.send(exception_method) if  @controller.uas_proxy.respond_to?(exception_method)
		end

		def handle_exception(exception)
			if @controller.request.xhr?
				response = Rack::Response.new(exception.message, 500)
			else
				env = @controller.env
				wrapper = ActionDispatch::ExceptionWrapper.new(env, exception)
				status = wrapper.status_code
				env["action_dispatch.exception"] = wrapper.exception
				env["PATH_INFO"] = "/#{status}"
				response = Rails.application.routes.call(env)
			end

			final_response = handled_response(exception) || response.to_a
			EM.next_tick { @controller.env['async.callback'].call final_response }

			Rails.logger.error "Reported service error message:"
			Rails.logger.error exception.message
			Rails.logger.error exception.backtrace.join("\n") unless exception.is_a?(InternalServiceError)
		rescue Exception
			Rails.logger.error $!
			Rails.logger.error $!.backtrace.join("\n")
			response = Rack::Response.new("Internal Error: #{$!}", 500)
			EM.next_tick { @controller.env['async.callback'].call response.to_a }
		end
	end

	class InternalServiceError < StandardError
	end
end
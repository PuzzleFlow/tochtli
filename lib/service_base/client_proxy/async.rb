module ServiceBase
	module ClientProxy
		class Async < ClientProxy::Base
			protected

			def dispatch_command(command, *args, options, &block)
				final_command = block_given? && options.fetch(:final, true)
				reply_handler = AsyncReplyMessageHandler.new(self, block, final_command)
				@client.send(command, *args, reply_handler, options)
				throw :async if final_command
			end
		end

		class AsyncReplyMessageHandler < ReplyMessageHandler
			def initialize(client_proxy, callback, final_command)
				super client_proxy, callback
				@final_command = final_command
			end

			def call(reply)
				@callback.call(reply) if @callback
				finalize_response if @final_command
			rescue Exception
				handle_exception $!
			end

			private

			def finalize_response
				@controller.render unless @controller.performed?
				EM.next_tick { @controller.env['async.callback'].call @controller.to_a }
			end

			def handle_exception(exception)
				if @controller.rescue_with_handler(exception)
					return finalize_response
				elsif @controller.request.xhr?
					response = Rack::Response.new(exception.message, 500)
				else
					exceptions_app = Rails.application.config.exceptions_app || ActionDispatch::PublicExceptions.new(Rails.public_path)
					env = @controller.env
					wrapper = ActionDispatch::ExceptionWrapper.new(env, exception)
					status = wrapper.status_code
					env["action_dispatch.exception"] = wrapper.exception
					env["PATH_INFO"] = "/#{status}"
					response = exceptions_app.call(env)
					if response[0] == 404 # Not found
						response = Rack::Response.new(exception.message, 500)
					end
				end

				EM.next_tick { @controller.env['async.callback'].call response }

				@controller.logger.error "Reported service error message:"
				@controller.logger.error exception.message
				@controller.logger.error exception.backtrace.join("\n") unless exception.is_a?(InternalServiceError)
			rescue Exception
				@controller.logger.error $!
				@controller.logger.error $!.backtrace.join("\n")
				response = Rack::Response.new("Internal Error: #{$!}", 500)
				EM.next_tick { @controller.env['async.callback'].call response.to_a }
			end
		end
	end
end
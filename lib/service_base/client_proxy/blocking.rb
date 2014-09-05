module ServiceBase
	module ClientProxy
		class Blocking < ClientProxy::Base

			DEFULT_TIMEOUT = 2.seconds

			protected

			def initialize(client, controller)
				super
			end

			def dispatch_command(command, *args, options, &block)
				reply_handler = BlockingReplyMessageHandler.new(self, Thread.current)
				timeout = options.fetch(:timeout, DEFULT_TIMEOUT)
				final_command = block && options.fetch(:final, true)
				@client.send(command, *args, reply_handler, options)
				if final_command
					sleep timeout
					if reply_handler.exception
						raise reply_handler.exception
					elsif reply_handler.reply
						block.call(reply_handler.reply)
					else # timeout
						raise TimeoutError, "Timeout on command: #{@client.class}##{command}"
					end
				end
			end
		end

		class BlockingReplyMessageHandler < ReplyMessageHandler
			attr_reader :reply, :exception

			def initialize(client_proxy, thread)
				super client_proxy, nil
				@thread = thread
			end

			def call(reply)
				@reply = reply
				@thread.run
			end

			private

			def handle_exception(exception)
				@exception = exception
				@thread.run
			end
		end
	end
end
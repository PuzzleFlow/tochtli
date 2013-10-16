module ServiceBase
	module Test
		class Integration < ActiveSupport::TestCase
			RabbitClient.rabbit_config = {:exchange_name => "puzzleflow.tests"}
			ControllerManager.queue_name_prefix = 'tests/'
			ControllerManager.queue_durable = false
			ControllerManager.queue_auto_delete = true

			setup do
				@client = ServiceBase::RabbitClient.new
				@connection = @client.rabbit_connection
				@controller_manager = ServiceBase::ControllerManager.instance
				@controller_manager.start(@connection)

				# Reply support
				@mutex = Mutex.new
				@cv = ConditionVariable.new
			end

			teardown do
				@controller_manager.stop
			end

			def publish(message, reply_message_class=nil, timeout=1.0)
				@reply = nil
				@reply_message_class = reply_message_class

				@client.reply_queue.register_message_handler message do |reply|
					@reply = reply
					assert_kind_of @reply_message_class, @reply, "Unexpected reply"
					@mutex.synchronize { @cv.signal }
				end
				@client.publish message

				if reply_message_class
					@mutex.synchronize { @cv.wait(@mutex, timeout) }

					raise "Reply on #{message.class.name} timeout" unless @reply
					raise @reply.message if @reply.is_a?(ServiceBase::ErrorMessage)

					@reply
				end
			end
		end
	end
end
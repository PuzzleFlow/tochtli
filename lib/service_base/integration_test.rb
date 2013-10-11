module ServiceBase
	class IntegrationTest < ActiveSupport::TestCase
		setup do
			@controller_manager = ServiceBase::ControllerManager.instance
			@controller_manager.start
			@connection = @controller_manager.rabbit_connection
			@channel = @connection.channel
			@reply_queue = @channel.queue('', exclusive: true, auto_delete: true)
			@exchange = @connection.exchange
			@reply_queue.bind(@exchange, routing_key: @reply_queue.name)

			# Reply support
			@mutex = Mutex.new
			@cv = ConditionVariable.new

			@reply_queue.subscribe(block: false) do |delivery_info, metadata, payload|
				assert_equal @reply_message_class.name.underscore, metadata.type, "Unexpected reply type"

				@reply = @reply_message_class.new
				@reply.from_json payload

				@mutex.synchronize { @cv.signal }
			end
		end

		teardown do
			@controller_manager.stop
		end

		def publish(message, reply_message_class=nil, timeout=1.0)
			@reply = nil
			@reply_message_class = reply_message_class

			@connection.publish message.routing_key, message, reply_to: @reply_queue.name
			if reply_message_class
				@mutex.synchronize { @cv.wait(@mutex, timeout) }

				raise "Reply on #{message.class.name} timeout" unless @reply

				@reply
			end
		end

	end
end
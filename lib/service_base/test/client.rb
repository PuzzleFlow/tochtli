module ServiceBase
	module Test
		class Client < ServiceBase::Test::TestCase

			setup do
				@logger = Rails.logger
				@client = ServiceBase::RabbitClient.new(@connection, @logger)
				@reply_queue = @client.reply_queue
			end

			def create_reply(reply_class, original_message, attributes)
				properties = TestMessageProperties.new(nil, reply_class.generate_id, original_message.id)
				reply_class.new(attributes, properties)
			end

			def handle_reply(reply_class, original_message, attributes)
				reply = create_reply(reply_class, original_message, attributes)
				@reply_queue.handle_reply reply
				reply
			end

		end
	end
end

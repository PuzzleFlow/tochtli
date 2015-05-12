require_relative 'test_helper'

class BaseClientTest < ServiceBase::Test::Client

	setup do
		@fake_client = FakeClient.new(@client)
	end

	test "instance" do
		assert_respond_to @fake_client, :rabbit_client
		assert_respond_to @fake_client, :rabbit_connection
	end

	test "synchronous method" do
		expect_published FakeMessage do
			handle_reply FakeReply, @message, result: 'OK'
		end

		result = @fake_client.do_sync

		assert_equal 'OK', result
	end

	test "asynchronous method" do
		result = nil
		@fake_client.do_async('attr') { |r| result = r }

		assert_published FakeMessage, test_attr: 'attr'
		handle_reply FakeReply, @message, result: 'OK'
		assert_equal 'OK', result
	end

	class FakeClient < ServiceBase::BaseClient
		def do_sync(attr=nil)
			handler = SyncMessageHandler.new
			timeout = 1
			@rabbit_client.publish FakeMessage.new(test_attr: attr), handler: handler, timeout: timeout
			reply = handler.wait!(timeout)
			reply.result
		end

		def do_async(attr, &block)
			handler = ->(reply) { block.call(reply.result) }
			timeout = 1
			@rabbit_client.publish FakeMessage.new(test_attr: attr), handler: handler, timeout: timeout
		end
	end

	class FakeMessage < ServiceBase::Message
		optional_attributes :test_attr
	end

	class FakeReply < ServiceBase::Message
		required_attributes :result
	end

end
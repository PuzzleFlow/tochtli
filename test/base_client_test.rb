require_relative 'test_helper'

class BaseClientTest < Minitest::Test
  include Tochtli::Test::Client

  def setup
    @fake_client = FakeClient.new(@client)
  end

  def test_instance
    assert_respond_to @fake_client, :rabbit_client
    assert_respond_to @fake_client, :rabbit_connection
  end

  def test_synchronous_method
    expect_published FakeMessage do
      handle_reply FakeReply, @message, result: 'OK'
    end

    result = @fake_client.do_sync

    assert_equal 'OK', result
  end

  def test_asynchronous_method
    result = nil
    @fake_client.do_async('attr') { |r| result = r }

    assert_published FakeMessage, test_attr: 'attr'
    handle_reply FakeReply, @message, result: 'OK'
    assert_equal 'OK', result
  end

  def test_dropped_message
    expect_published FakeMessage do
      @reply_queue.handle_reply Tochtli::MessageDropped.new("Message dropped", @message), @message.id
    end

    assert_raises Tochtli::MessageDropped do
      @fake_client.do_sync
    end
  end

  class FakeClient < Tochtli::BaseClient
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

  class FakeMessage < Tochtli::Message
    attribute :test_attr, type: String, presence: false
  end

  class FakeReply < Tochtli::Message
    attribute :result, type: String
  end

end

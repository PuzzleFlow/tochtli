require_relative 'test_helper'

class RabbitClientTest < Minitest::Test
  include Tochtli::Test::Client
  
  def test_reply_queue
    reply_queue = @client.reply_queue
    assert_kind_of Tochtli::ReplyQueue, reply_queue
    assert_equal @client.rabbit_connection, reply_queue.connection
    refute_nil reply_queue.name
  end

  def test_publishing
    @client.publish FakeMessage.new(test_attr: 'test')

    assert_published FakeMessage, test_attr: 'test'
  end

  def test_reply
    handler = Tochtli::Test::TestMessageHandler.new

    message = FakeMessage.new(test_attr: 'test')
    @client.publish message, handler: handler

    expected_reply = handle_reply(FakeReply, message, result: 'test123')

    assert_equal expected_reply, handler.reply
  end

  def test_reply_timeout
    handler = Tochtli::Test::TestMessageHandler.new
    message = FakeMessage.new(test_attr: 'test')
    @client.publish message, handler: handler, timeout: 0.05
    sleep 0.1
    assert_equal message, handler.timeout_message
  end

  def test_reply_no_timeout
    handler = Tochtli::Test::TestMessageHandler.new
    message = FakeMessage.new(test_attr: 'test')
    @client.publish message, handler: handler, timeout: 0.1

    expected_reply = create_reply(FakeReply, message, result: 'test123')
    @client.reply_queue.handle_reply expected_reply

    sleep 0.2

    assert_equal expected_reply, handler.reply
    assert_nil handler.timeout_message
  end

  def test_message_drop
    handler = Tochtli::Test::TestMessageHandler.new
    message = FakeMessage.new(test_attr: 'test')
    @client.publish message, handler: handler, timeout: 0.1
    @client.reply_queue.handle_reply Tochtli::MessageDropped.new("Message dropped", message), message.id

    assert_kind_of Tochtli::MessageDropped, handler.error
  end

  class FakeMessage < Tochtli::Message
    route_to 'test.fake.topic'

    attributes :test_attr
  end

  class FakeReply < Tochtli::Message
    attributes :result
  end

end

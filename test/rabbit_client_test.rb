require_relative 'test_helper'

class RabbitClientTest < Tochtli::Test::Client
  test "reply queue" do
    reply_queue = @client.reply_queue
    assert_kind_of Tochtli::ReplyQueue, reply_queue
    assert_equal @client.rabbit_connection, reply_queue.connection
    assert_not_nil reply_queue.name
  end

  test "publishing" do
    @client.publish FakeMessage.new(test_attr: 'test')

    assert_published FakeMessage, test_attr: 'test'
  end

  test "reply" do
    handler = Tochtli::Test::TestMessageHandler.new

    message = FakeMessage.new(test_attr: 'test')
    @client.publish message, handler: handler

    expected_reply = handle_reply(FakeReply, message, result: 'test123')

    assert_equal expected_reply, handler.reply
  end

  test "reply timeout" do
    handler = Tochtli::Test::TestMessageHandler.new
    message = FakeMessage.new(test_attr: 'test')
    @client.publish message, handler: handler, timeout: 0.05
    sleep 0.1
    assert_equal message, handler.timeout_message
  end

  test "reply no timeout" do
    handler = Tochtli::Test::TestMessageHandler.new
    message = FakeMessage.new(test_attr: 'test')
    @client.publish message, handler: handler, timeout: 0.1

    expected_reply = create_reply(FakeReply, message, result: 'test123')
    @client.reply_queue.handle_reply expected_reply

    sleep 0.2

    assert_equal expected_reply, handler.reply
    assert_nil handler.timeout_message
  end

  class FakeMessage < Tochtli::Message
    bind_topic 'test.fake.topic'

    attributes :test_attr
  end

  class FakeReply < Tochtli::Message
    attributes :result
  end

end

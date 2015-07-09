require_relative 'test_helper'
require 'benchmark'

class ControllerFunctionalTest < Tochtli::Test::Controller
  class TestMessage < Tochtli::Message
    route_to 'fn.test.echo'

    attribute :text, String
  end

  class CustomTopicMessage < Tochtli::Message
    attribute :resource, String

    attr_accessor :key

    def routing_key
      raise "Key not set" unless @key
      "fn.test.#{key}.accept"
    end
  end

  class TestEchoReply < Tochtli::Message
    attribute :original_text, String
  end

  class TestCustomReply < Tochtli::Message
    attribute :message, String
  end

  class TestController < Tochtli::BaseController
    bind prefix: 'fn.test', routing_key: 'fn.test.#'

    on TestMessage, :echo
    on CustomTopicMessage, routing_key: 'fn.test.1234.accept' do
      reply TestCustomReply.new(:message => "#{message.resource} accepted")
    end

    def echo
      reply TestEchoReply.new(:original_text => message.text)
    end
  end

  tests TestController

  def test_echo_command
    message = TestMessage.new(:text => 'Hello world!')

    publish message

    assert_kind_of TestEchoReply, @reply
    assert_equal message.text, @reply.original_text
  end

  def test_accept_command
    message = CustomTopicMessage.new(key: '1234', resource: 'Red car')

    publish message

    assert_kind_of TestCustomReply, @reply
    assert_equal "Red car accepted", @reply.message
  end
end
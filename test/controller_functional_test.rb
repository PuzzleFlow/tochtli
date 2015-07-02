require_relative 'test_helper'
require 'benchmark'

class ControllerFunctionalTest < Tochtli::Test::Controller
  class TestMessage < Tochtli::Message
    bind_topic 'fn.test.controller.echo'

    attributes :text
  end

  class TestEchoReply < Tochtli::Message
    attributes :original_text
  end

  class TestController < Tochtli::BaseController
    subscribe 'fn.test.controller.*'

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
end
require_relative 'test_helper'

class MessageTest < Minitest::Test
  include Tochtli::Test::Helpers

  class SimpleMessage < Tochtli::Message
    route_to 'test.controller.simple'

    attribute :text, type: String
    attribute :timestamp, type: Time
    attribute :optional, type: String, presence: false, format: /\A[a-z!]+\z/i

    def validate
      setup_timestamp
      super
    end

    def setup_timestamp
      self.timestamp ||= Time.now
    end
  end

  class OpenMessage < Tochtli::Message
    ignore_extra_attributes

    attribute :text, type: String
  end

  def test_routing_key
    assert_equal 'test.controller.simple', SimpleMessage.routing_key
  end

  def test_simple_message_without_optional
    message = SimpleMessage.new(text: 'Hello')
    assert_equal 'Hello', message.text
    assert_nil message.optional
    assert message.valid?
  end

  def test_simple_message_with_optional
    message = SimpleMessage.new(text: 'Hello', optional: 'world!')
    assert_equal 'Hello', message.text
    assert_equal 'world!', message.optional
    assert message.valid?
  end

  def test_invalid_attribute
    message = SimpleMessage.new(text: 'Hello', optional: 'world 123')
    assert message.invalid?, "Message passed validation when it should not"
    refute_nil message.errors.for(:optional).empty?
  end

  def test_validation_callback_without_value
    message = SimpleMessage.new(text: 'Hello')
    assert message.valid?
    assert_kind_of Time, message.timestamp
  end

  def test_validation_callbacks_with_given_value
    timestamp = Time.at(0) # long long ago
    message   = SimpleMessage.new(text: 'Hello', timestamp: timestamp)
    assert message.valid?
    assert_equal timestamp, message.timestamp
  end

  def test_undefined_attribute_error
    message = SimpleMessage.new(text: 'Hello', extra: 'from Paris')
    refute message.valid?, 'Message should not be valid' # Undefined attribute :extra
    refute message.errors.for(:extra).empty?
  end

  def test_ignore_excess_attribute
    message = OpenMessage.new(text: 'Hello', extra: 'from Paris')
    assert message.valid?
  end

end

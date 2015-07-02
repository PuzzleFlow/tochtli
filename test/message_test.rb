require_relative 'test_helper'

class MessageTest < Tochtli::Test::TestCase
  class SimpleMessage < Tochtli::Message
    bind_topic 'test.controller.simple'

    required_attributes :text, :timestamp
    optional_attributes :optional

    def valid?
      @timestamp ||= Time.now
      super
    end

    #validates :optional, format: /\A[a-z!]+\z/i, allow_nil: true

    def setup_timestamp
      @timestamp ||= Time.now
    end
  end

  class OpenMessage < Tochtli::Message
    ignore_excess_attributes

    required_attributes :text
  end

  def test_topic_binding
    message_class = Tochtli::MessageMap.instance.for('test.controller.simple')
    assert_equal SimpleMessage, message_class
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
    assert message.invalid?
    #assert_equal 'Undefined attribute :extra', message.errors.full_messages.first
  end

  def test_ignore_excess_attribute
    message = OpenMessage.new(text: 'Hello', extra: 'from Paris')
    assert message.valid?
  end

end

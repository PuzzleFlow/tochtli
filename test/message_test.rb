require_relative 'test_helper'

class MessageTest < Tochtli::Test::TestCase
  class SimpleMessage < Tochtli::Message
    bind_topic 'test.controller.simple'

    required_attributes :text, :timestamp
    optional_attributes :optional

    before_validation :setup_timestamp

    validates :optional, format: /\A[a-z!]+\z/i, allow_nil: true

    def setup_timestamp
      @timestamp ||= Time.now
    end
  end

  class OpenMessage < Tochtli::Message
    ignore_excess_attributes

    required_attributes :text
  end

  test 'topic binding' do
    message_class = Tochtli::MessageMap.instance.for('test.controller.simple')
    assert_equal SimpleMessage, message_class
  end

  test 'simple message without optional' do
    message = SimpleMessage.new(text: 'Hello')
    assert_equal 'Hello', message.text
    assert_nil message.optional
    assert message.valid?
  end

  test 'simple message with optional' do
    message = SimpleMessage.new(text: 'Hello', optional: 'world!')
    assert_equal 'Hello', message.text
    assert_equal 'world!', message.optional
    assert message.valid?
  end

  test 'invalid attribute' do
    message = SimpleMessage.new(text: 'Hello', optional: 'world 123')
    assert message.invalid?
  end

  test 'validation callback without value' do
    message = SimpleMessage.new(text: 'Hello')
    assert message.valid?
    assert_kind_of Time, message.timestamp
  end

  test 'validation callbacks with given value' do
    timestamp = Time.at(0) # long long ago
    message   = SimpleMessage.new(text: 'Hello', timestamp: timestamp)
    assert message.valid?
    assert_equal timestamp, message.timestamp
  end

  test 'undefined attribute error' do
    message = SimpleMessage.new(text: 'Hello', extra: 'from Paris')
    assert message.invalid?
    assert_equal 'Undefined attribute :extra', message.errors.full_messages.first
  end

  test 'ignore excess attribute' do
    message = OpenMessage.new(text: 'Hello', extra: 'from Paris')
    assert message.valid?
  end

end

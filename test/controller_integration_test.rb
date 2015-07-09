require_relative 'test_helper'
require 'benchmark'

Thread.abort_on_exception = true

class ControllerIntegrationTest < Tochtli::Test::Integration
  class TestMessage < Tochtli::Message
    route_to 'test.controller.echo'

    attribute :text, String
  end

  class ErrorMessage < Tochtli::Message
    route_to 'test.controller.error'
  end

  class FailureMessage < Tochtli::Message
    route_to 'test.controller.failure'
  end

  class SleepyMessage < Tochtli::Message
    route_to 'test.controller.sleepy'

    attribute :duration, Float
  end

  class TestEchoReply < Tochtli::Message
    attribute :original_text, String
  end

  class TestController < Tochtli::BaseController
    bind 'test.controller.*'

    self.work_pool_size = 10

    on TestMessage, :echo
    on ErrorMessage, :error
    on FailureMessage, :failure
    on SleepyMessage, :sleepy

    def echo
      reply TestEchoReply.new(:original_text => message.text)
    end

    def error
      raise "Error"
    end

    def failure
      @rabbit_connection.connection.close # simulate network failure
    end

    def sleepy
      sleep message.duration
      reply TestEchoReply.new(:original_text => "Done after #{message.duration}s")
    end
  end

  class CustomNameController < Tochtli::BaseController
    self.queue_name = 'test/custom/queue/name'
  end

  class CustomExchangeController < Tochtli::BaseController
    self.queue_name       = ''
    self.queue_durable    = false
    self.queue_exclusive  = true
    self.exchange_type    = :fanout
    self.exchange_name    = 'test.notifications'
    self.exchange_durable = false
  end

  class BeforeSetupBindingController < Tochtli::BaseController
    before_setup do
      bind 'custom.topic'
    end
  end

  class TestReplyHandler
    attr_reader :pending_replies, :errors, :timeouts

    def initialize(expected_replies)
      @pending_replies = expected_replies
      @errors          = 0
      @timeouts        = 0
      @mutex           = Mutex.new
      @cv              = ConditionVariable.new
    end

    def call(reply)
      @mutex.synchronize do
        @pending_replies -= 1
        @cv.signal if done?
      end
    end

    def on_error(reply)
      @errors += 1
      call(reply)
    end

    def on_timeout(original_message)
      @timeouts += 1
      call(nil)
    end

    def wait(timeout)
      timeout = timeout.to_f unless timeout.nil? # ensure it is numerical, e.g. for Rubinius compatibility
      @mutex.synchronize { done? || @cv.wait(@mutex, timeout) }
    end

    protected

    def done?
      @pending_replies == 0
    end
  end

  def test_echo_command
    message = TestMessage.new(:text => 'Hello world!')

    publish message, :expect => TestEchoReply

    assert_equal message.text, @reply.original_text
  end

  def test_error
    message = ErrorMessage.new
    handler = TestReplyHandler.new(1)

    publish message, :reply_handler => handler, :timeout => 1.5

    handler.wait(2)

    assert_equal 1, handler.errors
  end

  def test_network_failure
    message = FailureMessage.new
    handler = TestReplyHandler.new(1)

    publish message, :reply_handler => handler, :timeout => 2.5

    handler.wait(3)

    assert_equal 1, handler.timeouts
  end

  def test_sleepy
    count   = 20
    handler = TestReplyHandler.new(count)
    start_t = Time.now
    count.times do
      message = SleepyMessage.new(:duration => 0.2)
      publish message, :expect => TestEchoReply, :reply_handler => handler, :timeout => 3.0
    end

    handler.wait(4)

    duration = Time.now - start_t

    assert_equal 0, handler.errors
    assert_equal 0, handler.timeouts
    assert duration < 3.0, "The total processing time should be less then the processing time sum (multi customers expected), duration: #{duration}s"
  end

  def restart_test(timeout)
    count   = 20
    handler = TestReplyHandler.new(count)
    count.times do
      message = SleepyMessage.new(:duration => 0.5)
      publish message, :expect => TestEchoReply, :reply_handler => handler, :timeout => 3.0
    end
    sleep(0.3)
    refute_equal 0, handler.pending_replies

    # right now there should be some messages not processed
    # restart should wait until they are done

    TestController.restart(timeout: timeout)
    handler.wait(4)

    handler
  end

  def test_graceful_restart
    handler = restart_test(15)

    assert_equal 0, handler.pending_replies
    assert_equal 0, handler.errors
    assert_equal 0, handler.timeouts
  end

  def test_forced_restart
    handler = restart_test(0)

    assert_equal 0, handler.pending_replies
    refute_equal 0, handler.errors + handler.timeouts
  end


  def test_echo_performance
    begin
      @logger.level = Logger::ERROR # mute logger to speed up test

      count   = 200
      handler = TestReplyHandler.new(count)

      start_t = Time.now

      count.times do |i|
        message = TestMessage.new(:text => "#{i}: Hello world!")
        publish message, :expect => TestEchoReply, :reply_handler => handler, :timeout => 6
      end

      handler.wait(2)

      end_t = Time.now
      time  = end_t - start_t

      assert_equal 0, handler.errors
      assert_equal 0, handler.timeouts
      assert_equal 0, handler.pending_replies

      puts "Published: #{count} in #{time} (#{count/time}req/s)"
    ensure
      @logger.level = Logger::DEBUG
    end
  end

  def test_default_queue_name
    assert_equal 'controller_integration_test/test_controller', TestController.queue_name
    assert @connection.queue_exists?('controller_integration_test/test_controller')
  end

  def test_custom_queue_name
    assert_equal 'test/custom/queue/name', CustomNameController.queue_name
    assert @connection.queue_exists?('test/custom/queue/name')
  end

  def test_custom_exchange
    dispatcher = CustomExchangeController.dispatcher
    queue      = dispatcher.queues.first
    refute_nil dispatcher
    refute_nil queue
    assert_equal '', CustomExchangeController.queue_name
    assert_match /^amq.gen/, queue.name
    refute queue.durable?
    assert queue.exclusive?
    assert queue.server_named?
    refute_nil queue.channel.exchanges['test.notifications']
    refute queue.channel.exchanges['test.notifications'].durable?
  end

  def test_binding_on_setup
    assert BeforeSetupBindingController.routing_keys.include?('custom.topic')
  end
end

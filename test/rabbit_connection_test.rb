require_relative 'test_helper'
require 'tochtli/test/test_case'

class RabbitConnectionTest < ActiveSupport::TestCase
  setup do
    Tochtli::RabbitConnection.close('test')
  end

  teardown do
    Tochtli::RabbitConnection.close('test')
  end

  class TestMessage < Tochtli::Message
    attributes :text
  end

  test "connection with default options" do
    Tochtli::RabbitConnection.open('test') do |connection|
      assert_equal "puzzleflow.services", connection.exchange.name
    end
  end

  test "connection with custom options" do
    Tochtli::RabbitConnection.open('test', exchange_name: "puzzleflow.tests") do |connection|
      assert_equal "puzzleflow.tests", connection.exchange.name
    end
  end

  test "multiple channels and exchanges" do
    Tochtli::RabbitConnection.open('test', exchange_name: "puzzleflow.tests") do |connection|
      another_thread = Thread.new {}

      current_channel = connection.channel
      another_channel = connection.channel(another_thread)

      current_exchange = connection.exchange
      another_exchange = connection.exchange(another_thread)

      assert_not_equal current_channel, another_channel
      assert_not_equal current_exchange, another_exchange
      assert_equal "puzzleflow.tests", current_exchange.name
      assert_equal "puzzleflow.tests", another_exchange.name
    end
  end

  test "queue creation and existance" do
    Tochtli::RabbitConnection.open('test') do |connection|
      queue = connection.queue('test-queue', [], auto_delete: true)
      assert_not_nil queue
      assert_equal 'test-queue', queue.name
      assert connection.queue_exists?('test-queue')
    end
  end

  test "reply queue recovery" do
    Tochtli::RabbitConnection.open('test',
                                       network_recovery_interval:     0.1,
                                       recover_from_connection_close: true) do |rabbit_connection|
      reply_queue   = rabbit_connection.reply_queue
      original_name = reply_queue.name
      timeout       = 0.3

      message = TestMessage.new(text: "Response")
      reply   = TestMessage.new(text: "Reply")
      handler = Tochtli::Test::TestMessageHandler.new
      reply_queue.register_message_handler message, handler, timeout

      rabbit_connection.publish reply_queue.name, reply, correlation_id: message.id, timeout: timeout
      sleep timeout

      assert_not_nil handler.reply

      # simulate network failure
      rabbit_connection.connection.handle_network_failure(RuntimeError.new('fake connection error'))
      sleep 0.1 until rabbit_connection.open? # wait for recovery
      assert_not_equal original_name, reply_queue.name, "Recovered queue should have re-generated name"

      message = TestMessage.new(text: "Response")
      reply   = TestMessage.new(text: "Reply")
      handler = Tochtli::Test::TestMessageHandler.new
      reply_queue.register_message_handler message, handler, timeout

      rabbit_connection.publish reply_queue.name, reply, correlation_id: message.id, timeout: timeout
      sleep timeout

      assert_not_nil handler.reply
    end
  end

  test "multithreaded consumer performance" do
    work_pool_size = 10
    Tochtli::RabbitConnection.open('test',
                                       exchange_name:  "puzzleflow.tests",
                                       work_pool_size: work_pool_size) do |connection|
      mutex                  = Mutex.new
      cv                     = ConditionVariable.new
      thread_count           = 5
      message_count          = 100
      expected_message_count = message_count*thread_count

      consumed         = 0
      consumed_mutex   = Mutex.new
      consumer_threads = Set.new
      consumer         = Proc.new do |delivery_info, metadata, payload|
        consumed_mutex.synchronize { consumed += 1 }
        consumer_threads << Thread.current
        connection.publish metadata.reply_to, TestMessage.new(text: "Response to #{payload}")
      end

      queue = connection.channel.queue('', auto_delete: true)
      queue.bind(connection.exchange, routing_key: queue.name)
      queue.subscribe(block: false, &consumer)

      replies        = 0
      reply_consumer = Proc.new do |delivery_info, metadata, payload|
        replies += 1
        mutex.synchronize { cv.signal } if replies == expected_message_count
      end

      reply_queue = connection.channel.queue('', auto_delete: true)
      reply_queue.bind(connection.exchange, routing_key: reply_queue.name)
      reply_queue.subscribe(block: false, &reply_consumer)

      start_t = Time.now

      threads = (1..thread_count).collect do
        t                    = Thread.new do
          message_count.times do |i|
            connection.publish queue.name, TestMessage.new(text: "Message #{i}"),
                               reply_to: reply_queue.name
          end
        end
        t.abort_on_exception = true
        t
      end

      threads.each(&:join)

      mutex.synchronize { cv.wait(mutex, 5.0) }

      end_t = Time.now
      time  = end_t - start_t

      assert_equal expected_message_count, consumed
      assert_equal expected_message_count, replies
      assert_equal work_pool_size, consumer_threads.size

      puts "Published: #{expected_message_count} in #{time} (#{expected_message_count/time}req/s)"
    end
  end
end

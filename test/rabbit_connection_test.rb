require_relative 'test_helper'

class RabbitConnectionTest < ActiveSupport::TestCase
	test "connection with default options" do
		connection = ServiceBase::RabbitConnection.new
		connection.connect do
			assert_equal "puzzleflow.services", connection.exchange.name
		end
	end

	test "connection with custom options" do
		connection = ServiceBase::RabbitConnection.new(:exchange_name => "puzzleflow.tests")
		connection.connect do
			assert_equal "puzzleflow.tests", connection.exchange.name
		end
	end

	test "multiple channels and exchanges" do
		connection = ServiceBase::RabbitConnection.new(:exchange_name => "puzzleflow.tests")
		connection.connect do
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

	class TestMessage < ServiceBase::Message
			attributes :text
	end

	test "multithreaded consumer performance" do
		work_pool_size = 10
		connection = ServiceBase::RabbitConnection.new(:exchange_name => "puzzleflow.tests",
																									 :work_pool_size => work_pool_size)
		connection.connect do
			mutex = Mutex.new
			cv = ConditionVariable.new
			thread_count = 5
			message_count = 1_000
			expected_message_count = message_count*thread_count

			consumed = 0
			consumer_threads = Set.new
			consumer = Proc.new do |delivery_info, metadata, payload|
				consumed += 1
				consumer_threads << Thread.current
				connection.publish metadata.reply_to, TestMessage.new(text: "Response to #{payload}"), mandatory: true
			end

			queue = connection.channel.queue('', auto_delete: true)
			queue.bind(connection.exchange, routing_key: queue.name)
			queue.subscribe(block: false, &consumer)

			replies = 0
			reply_consumer = Proc.new do |delivery_info, metadata, payload|
				replies += 1
				mutex.synchronize { cv.signal } if replies == expected_message_count
			end

			reply_queue = connection.channel.queue('', auto_delete: true)
			reply_queue.bind(connection.exchange, routing_key: reply_queue.name)
			reply_queue.subscribe(block: false, &reply_consumer)

			start_t = Time.now

			threads = (1..thread_count).collect do
				t = Thread.new do
					message_count.times do |i|
						connection.publish queue.name, TestMessage.new(text: "Message #{i}"),
															 mandatory: true, reply_to: reply_queue.name
					end
				end
				t.abort_on_exception = true
				t
			end

			threads.each(&:join)

			mutex.synchronize { cv.wait(mutex, 20.0) }

			end_t = Time.now
			time = end_t - start_t

			assert_equal expected_message_count, consumed
			assert_equal expected_message_count, replies
			assert_equal work_pool_size, consumer_threads.size

			puts "Published: #{expected_message_count} in #{time} (#{expected_message_count/time}req/s)"
		end
	end
end
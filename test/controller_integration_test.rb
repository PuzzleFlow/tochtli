require_relative 'test_helper'
require 'benchmark'

Thread.abort_on_exception = true

class ControllerIntegrationTest < ServiceBase::Test::Integration
	class TestMessage < ServiceBase::Message
		bind_topic 'test.controller.echo'

		attributes :text
	end

	class ErrorMessage < ServiceBase::Message
		bind_topic 'test.controller.error'
	end

	class FailureMessage < ServiceBase::Message
		bind_topic 'test.controller.failure'
	end

	class SleepyMessage < ServiceBase::Message
		bind_topic 'test.controller.sleepy'

		attributes :duration
	end

	class TestEchoReply < ServiceBase::Message
		attributes :original_text
	end

	class TestController < ServiceBase::BaseController
		subscribe 'test.controller.*'

		self.work_pool_size = 10

		def echo
			reply TestEchoReply.new(:original_text => message.text)
		end

		def error
			raise "Error"
		end

		def failure
			@rabbit_connection.connection.close # simulate network failure
			reply TestEchoReply.new(:original_text => 'should not get it')
		end

		def sleepy
			sleep message.duration
			reply TestEchoReply.new(:original_text => "Done after #{message.duration}s")
		end
	end

	class CustomNameController < ServiceBase::BaseController
		self.queue_name = 'test/custom/queue/name'
	end

	class CustomExchangeController < ServiceBase::BaseController
		self.queue_name = ''
		self.queue_durable = false
		self.queue_exclusive = true
		self.exchange_type = :fanout
		self.exchange_name = 'test.notifications'
		self.exchange_durable = false
	end

	class BeforeSetupBindingController < ServiceBase::BaseController
		before_setup do
			subscribe 'custom.topic'
		end
	end

	class TestReplyHandler
		attr_reader :pending_replies, :errors, :timeouts

		def initialize(expected_replies)
			@pending_replies  = expected_replies
			@errors           = 0
			@timeouts         = 0
			@mutex            = Mutex.new
			@cv               = ConditionVariable.new
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

	test 'echo command' do
		message = TestMessage.new(:text => 'Hello world!')

		publish message, :expect => TestEchoReply

		assert_equal message.text, @reply.original_text
	end

	test 'error' do
		message = ErrorMessage.new
		handler = TestReplyHandler.new(1)

		publish message, :reply_handler => handler, :timeout => 1.5.second

		handler.wait(2.seconds)

		assert_equal 1, handler.errors
	end

	test 'network failure' do
		message = FailureMessage.new
		handler = TestReplyHandler.new(1)

		publish message, :reply_handler => handler, :timeout => 1.5.second

		handler.wait(2.seconds)

		assert_equal 1, handler.timeouts
	end

	test 'sleepy' do
		count   = 20
		handler = TestReplyHandler.new(count)
		start_t = Time.now
		count.times do
			message = SleepyMessage.new(:duration => 0.1)
			publish message, :expect => TestEchoReply, :reply_handler => handler, :timeout => 2.0
		end

		handler.wait(3.seconds)

		duration = Time.now - start_t

		assert_equal 0, handler.errors
		assert_equal 0, handler.timeouts
		assert duration < 1.5, "The total processing time should be less then the processing time sum (multi customers expected), duration: #{duration}s"
	end

	test 'echo performance' do
		begin
			@logger.level = Logger::ERROR # mute logger to speed up test

			count   = 500
			handler = TestReplyHandler.new(count)

			start_t = Time.now

			count.times do |i|
				message = TestMessage.new(:text => "#{i}: Hello world!")
				publish message, :expect => TestEchoReply, :reply_handler => handler, :timeout => 6.seconds
			end

			handler.wait(2.seconds)

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

	test 'default queue name' do
		assert_equal 'controller_integration_test/test_controller', TestController.queue_name
		assert @connection.queue_exists?('controller_integration_test/test_controller')
	end

	test 'custom queue name' do
		assert_equal 'test/custom/queue/name', CustomNameController.queue_name
		assert @connection.queue_exists?('test/custom/queue/name')
	end

	test 'custom exchange' do
		dispatcher = CustomExchangeController.dispatcher
		refute_nil dispatcher
		assert_equal '', CustomExchangeController.queue_name
		refute_nil dispatcher.queue
		assert_match /^amq.gen/, dispatcher.queue.name
		refute dispatcher.queue.durable?
		assert dispatcher.queue.exclusive?
		assert dispatcher.queue.server_named?
		refute_nil dispatcher.queue.channel.exchanges['test.notifications']
		refute dispatcher.queue.channel.exchanges['test.notifications'].durable?
	end

	test 'binding on setup' do
		assert BeforeSetupBindingController.routing_keys.include?('custom.topic')
	end
end

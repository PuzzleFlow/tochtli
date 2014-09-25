require_relative 'test_helper'
require 'benchmark'

Thread.abort_on_exception = true

class ControllerTest < ServiceBase::Test::Integration
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

	class TestEchoReply < ServiceBase::Message
		attributes :original_text
	end

	class TestController < ServiceBase::BaseController
		subscribe 'test.controller.*'

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
				@cv.signal if @pending_replies == 0
			end
		end

		def on_error(reply)
			@errors += 1
		end

		def on_timeout(original_message)
			@timeouts += 1
		end

		def wait(timeout)
			@mutex.synchronize { @cv.wait(@mutex, timeout) }
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

		publish message, :reply_handler => handler, :timeout => 0.1.second

		handler.wait(0.15.seconds)

		assert_equal 1, handler.errors
	end

	test 'network failure' do
		message = FailureMessage.new
		handler = TestReplyHandler.new(1)

		publish message, :reply_handler => handler, :timeout => 0.1.second

		handler.wait(2.seconds)

		assert_equal 1, handler.timeouts
	end

	test 'echo performance' do
		begin
			@logger.level = Logger::ERROR # mute logger to speed up test

			count   = 2_000
			handler = TestReplyHandler.new(count)

			start_t = Time.now

			count.times do |i|
				message = TestMessage.new(:text => "#{i}: Hello world!")
				publish message, :expect => TestEchoReply, :reply_handler => handler, :timeout => 6.seconds
			end

			handler.wait(6.seconds)

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
end
require_relative 'test_helper'

require 'celluloid/zmq'

Celluloid::ZMQ.init

class CelluloidPerformanceTest < ActiveSupport::TestCase

	class Server
		include Celluloid::ZMQ

		def initialize(address)
			@socket = PullSocket.new

			begin
				@socket.bind(address)
			rescue IOError
				@socket.close
				raise
			end
		end

		def run
			loop { async.handle_message @socket.read }
		end

		def handle_message(message)
			nil
		end
	end

	class Client
		include Celluloid::ZMQ

		def initialize(address)
			@socket = PushSocket.new

			begin
				@socket.connect(address)
			rescue IOError
				@socket.close
				raise
			end
		end

		def write(message)
			@socket.send(message)

			nil
		end
	end

	MESSAGE_COUNT = 10**3
	THREADS = 100

	def setup
		Celluloid.boot unless Celluloid.internal_pool.running?

		@addr = 'tcp://127.0.0.1:3435'

		@server = Server.new(@addr)
		@client = Client.new(@addr)

		@server.async.run
	end

	def teardown
		#@server.terminate
	end

	def test_performance
		Benchmark.bm do |x|
			x.report "#{THREADS} x #{MESSAGE_COUNT} messages" do
				threads = (0..THREADS).collect do
					client = Client.new(@addr)
					thread = Thread.new do
						MESSAGE_COUNT.times do
							client.write 'hi'
						end
					end
					[thread, client]
				end
				threads.each do |thread, client|
					thread.join
					#client.terminate
				end
			end
		end
	end
end


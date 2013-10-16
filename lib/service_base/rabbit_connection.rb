require 'bunny'
require 'securerandom'

module ServiceBase
	class RabbitConnection
		attr_accessor :connection, :channel, :exchange

		def initialize(config = nil)
			@config = RabbitConnection::Config.load(config)
		end

		def connect
			return if open?

			setup_bunny_connection

			if block_given?
				yield
				disconnect
			end
		end

		def disconnect
			@channel.close if @channel
			@connection.close if @connection
			@channel, @connection, @exchange = nil, nil, nil
		end

		def open?
			@connection && @connection.open?
		end

		def setup_bunny_connection
			bunny_config = {}.merge(@config)
			exchange_name = bunny_config.delete(:exchange_name)

			@connection = Bunny.new(bunny_config)
			@connection.start

			@channel = @connection.create_channel

			@exchange = @channel.topic(exchange_name, durable: true)

		rescue Bunny::TCPConnectionFailed => ex
			raise ConnectionFailed.new("Unable to connect to: '#{bunny_config.url}': #{ex.message}")
		rescue Bunny::PreconditionFailed => ex
			raise ConnectionFailed.new("Unable create exchange: '#{exchange_name}': #{ex.message}")
		end

		def queue(name, routing_keys=[], options={})
			queue = @channel.queue(name, {durable: true}.merge(options))
			routing_keys.each do |routing_key|
				queue.bind(@exchange, routing_key: routing_key)
			end
			queue
		end

		def wait_on_threads(timeout)
			@channel.work_pool.join(timeout)
		end

		def stop
			@channel.work_pool.kill
		end

		def ack(delivery_tag)
			@channel.ack(delivery_tag, false)
		end

		def publish(routing_key, message, options={})
			payload = message.to_json

			@exchange.publish(payload, {
					routing_key: routing_key,
					persistent: true,
					timestamp: Time.now.to_i,
					message_id: message.id,
					type: message.class.name.underscore,
					content_type: "application/json"
			}.merge(options)
			)
		end

		private

		def generate_id
			SecureRandom.uuid
		end

		class Config < Hash
			DEFAULTS = {
					:exchange_name => "puzzleflow.services",
					:automatically_recover => true,
					:network_recovery_interval => 1
			}

			def self.load(config=nil)
				if config.nil?
					config_path = Rails.root.join('config/rabbit.yml')
					if File.exist?(config_path)
						config = YAML.load_file(config_path)
					end
				elsif config.is_a?(String)
					config = YAML.load_file(config)
				end

				new.merge!(DEFAULTS.merge(config || {}))
			end
		end

		class ConnectionFailed < StandardError
		end
	end
end

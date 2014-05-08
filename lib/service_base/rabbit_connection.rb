require 'bunny'
require 'securerandom'

module ServiceBase
	class RabbitConnection
		attr_accessor :connection
		delegate :logger, to: :@connection

		def initialize(config = nil, channel_pool=nil)
			@config = config.is_a?(RabbitConnection::Config) ? config : RabbitConnection::Config.load(config)
			@exchange_name = @config.delete(:exchange_name)
			@work_pool_size = @config.delete(:work_pool_size)
			@channel_pool = channel_pool ? channel_pool : ChannelPool.new
		end

		def connect
			return if open?

			setup_bunny_connection

			if block_given?
				yield
				disconnect if open?
			end
		end

		def disconnect
			@channel_pool.close
			@connection.close if @connection
			@connection = nil
		end

		def open?
			@connection && @connection.open?
		end

		def setup_bunny_connection
			@connection = Bunny.new(@config)
			@connection.start
		rescue Bunny::TCPConnectionFailed => ex
			raise ConnectionFailed.new("Unable to connect to: '#{@config[:url]}': #{ex.message}")
		end

		def exchange(thread=Thread.current)
			channel_wrap(thread).exchange
		end

		def channel(thread=Thread.current)
			channel_wrap(thread).channel
		end

		def queue(name, routing_keys=[], options={})
			queue = channel.queue(name, {durable: true}.merge(options))
			routing_keys.each do |routing_key|
				queue.bind(exchange, routing_key: routing_key)
			end
			queue
		end

		def ack(delivery_tag)
			channel.ack(delivery_tag, false)
		end

		def publish(routing_key, message, options={})
			payload = message.to_json
			exchange.on_return do |return_info, properties, content|
				logger.error "Message #{properties[:message_id]} dropped: #{return_info[:reply_text]} [#{return_info[:reply_code]}]"
			end

			exchange.publish(payload, {
					routing_key: routing_key,
					persistent: true,
					timestamp: Time.now.to_i,
					message_id: message.id,
					type: message.class.name.underscore,
					content_type: "application/json"
			}.merge(options))
		end

		private

		def create_channel_wrap(thread=Thread.current)
			raise ConnectionFailed.new("Channel already created for thread #{thread.object_id}") if @channel_pool[thread.object_id]

			channel = @connection.create_channel(nil, @work_pool_size)
			exchange = channel.topic(@exchange_name, durable: true)

			channel_wrap = ChannelWrap.new(channel, exchange)
			@channel_pool[thread.object_id] = channel_wrap

			channel_wrap
		rescue Bunny::PreconditionFailed => ex
			raise ConnectionFailed.new("Unable create exchange: '#{@exchange_name}': #{ex.message}")
		end

		def channel_wrap(thread=Thread.current)
			@channel_pool[thread.object_id] || create_channel_wrap(thread)
		end

		def generate_id
			SecureRandom.uuid
		end

		class ChannelWrap
			attr_reader :channel, :exchange

			def initialize(channel, exchange)
				@channel = channel
				@exchange = exchange
			end
		end

		class ChannelPool < Hash
			def close
				each_value {|wrap| wrap.channel.close }
			end
		end

		class Config < Hash
			DEFAULTS = {
					:exchange_name => "puzzleflow.services",
					:work_pool_size => 1,
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

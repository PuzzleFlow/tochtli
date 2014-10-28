require 'bunny'
require 'securerandom'

module ServiceBase
	class RabbitConnection
		attr_accessor :connection
		delegate :logger, to: :@connection

		def initialize(config = nil, channel_pool=nil)
			@config         = config.is_a?(RabbitConnection::Config) ? config : RabbitConnection::Config.load(config)
			@exchange_name  = @config.delete(:exchange_name)
			@work_pool_size = @config.delete(:work_pool_size)
			@channel_pool   = channel_pool ? channel_pool : Hash.new
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
			@connection.close if @connection
		rescue Bunny::ClientTimeout
			false
		ensure
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
			queue = channel.queue(name, { durable: true }.merge(options))
			routing_keys.each do |routing_key|
				queue.bind(exchange, routing_key: routing_key)
			end
			queue
		end

		def queue_exists?(name)
			@connection.queue_exists?(name)
		end

		def ack(delivery_tag)
			channel.ack(delivery_tag, false)
		end

		def publish(routing_key, message, options={})
			begin
				payload = message.to_json
			rescue Exception
				raise "Unable to serialize message to JSON: #{$!}"
			end

			exchange.on_return do |return_info, properties, content|
				logger.error "Message #{properties[:message_id]} dropped: #{return_info[:reply_text]} [#{return_info[:reply_code]}]"
			end

			exchange.publish(payload, {
					routing_key:  routing_key,
					persistent:   true,
					mandatory:    true,
					timestamp:    Time.now.to_i,
					message_id:   message.id,
					type:         message.class.name.underscore,
					content_type: "application/json"
			}.merge(options))
		end

		private

		def create_channel_wrap(thread=Thread.current)
			raise ConnectionFailed.new("Channel already created for thread #{thread.object_id}") if @channel_pool[thread.object_id]
			raise ConnectionFailed.new("Unable to create channel. Connection lost.") unless @connection

			channel  = @connection.create_channel(nil, @work_pool_size)
			exchange = channel.topic(@exchange_name, durable: true)

			channel_wrap                    = ChannelWrap.new(channel, exchange)
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
				@channel  = channel
				@exchange = exchange
			end
		end

		class Config < Hash
			DEFAULTS = {
					:exchange_name             => "puzzleflow.services",
					:work_pool_size            => 1,
					:automatically_recover     => true,
					:network_recovery_interval => 1
			}

			def self.load(config=nil)
				config = case config
									 when String
										 YAML.load_file(config).symbolize_keys
									 when Hash
										 config.symbolize_keys
									 when nil
										 {}
									 else
										 raise "Unexpected configuration: #{config.inspect}, Hash or String expected."
								 end

				defaults = DEFAULTS

				if defined?(Rails)
					config_path = Rails.root.join('config/rabbit.yml')
					if config_path.exist?
						rails_config = YAML.load_file(config_path)
						raise "Unexpected rabbit.yml: #{rails_config.inspect}, Hash expected." unless rails_config.is_a?(Hash)
						defaults = defaults.merge(rails_config.symbolize_keys)
					end
				end

				new.merge!(defaults.merge(config))
			end
		end

		class ConnectionFailed < StandardError
		end
	end
end

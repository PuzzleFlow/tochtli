require 'bunny'
require 'securerandom'

module Tochtli
  class RabbitConnection
    attr_accessor :connection
    attr_reader :logger, :exchange_name

    cattr_accessor :connections
    self.connections = {}

    private_class_method :new

    DEFAULT_CONNECTION_NAME = 'default'

    def initialize(config = nil, channel_pool=nil)
      @config         = config.is_a?(RabbitConnection::Config) ? config : RabbitConnection::Config.load(nil, config)
      @exchange_name  = @config.delete(:exchange_name)
      @work_pool_size = @config.delete(:work_pool_size)
      @logger         = @config.delete(:logger) || Tochtli.logger
      @channel_pool   = channel_pool ? channel_pool : Hash.new
    end

    def self.open(name=nil, config=nil)
      name ||= defined?(Rails) ? Rails.env : DEFAULT_CONNECTION_NAME
      raise ArgumentError, "RabbitMQ configuration name not specified" if !name && !ENV.has_key?('RABBITMQ_URL')
      connection = self.connections[name.to_sym]
      if !connection || !connection.open?
        config     = config.is_a?(RabbitConnection::Config) ? config : RabbitConnection::Config.load(name, config)
        connection = new(config)
        connection.connect
        self.connections[name.to_sym] = connection
      end

      if block_given?
        yield connection
        close name
      else
        connection
      end
    end

    def self.close(name=nil)
      name ||= defined?(Rails) ? Rails.env : nil
      raise ArgumentError, "RabbitMQ configuration name not specified" unless name
      connection = self.connections.delete(name.to_sym)
      connection.disconnect if connection && connection.open?
    end

    def connect(opts={})
      return if open?

      defaults = {}
      unless opts[:logger]
        defaults[:logger]       = @logger.dup
        defaults[:logger].level = Tochtli.debug_bunny ? Logger::DEBUG : Logger::WARN
      end

      setup_bunny_connection(defaults.merge(opts))

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
      @channel_pool.clear
      @connection  = nil
      @reply_queue = nil
    end

    def open?
      @connection && @connection.open?
    end

    def setup_bunny_connection(opts={})
      @connection = Bunny.new(@config, opts)
      @connection.start
    rescue Bunny::TCPConnectionFailed => ex
      connection_url = "amqp://#{@connection.user}@#{@connection.host}:#{@connection.port}/#{@connection.vhost}"
      raise ConnectionFailed.new("Unable to connect to: '#{connection_url}' (#{ex.message})")
    end

    def create_reply_queue
      Tochtli::ReplyQueue.new(self, @logger)
    end

    def reply_queue
      @reply_queue ||= create_reply_queue
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

    def queue_exists?(name)
      @connection.queue_exists?(name)
    end

    def ack(delivery_tag)
      channel.ack(delivery_tag, false)
    end

    def publish(routing_key, message, options={})
      begin
        payload = message.to_json
      rescue StandardError
        logger.error "Unable to serialize message: #{message.inspect}"
        logger.error $!
        raise "Unable to serialize message to JSON: #{$!}"
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

    def create_channel(consumer_pool_size = 1)
      @connection.create_channel(nil, consumer_pool_size).tap do |channel|
        channel.confirm_select # use publisher confirmations
      end
    end

    def create_exchange(channel)
      channel.topic(@exchange_name, durable: true)
    end

    private

    def on_return(return_info, properties, payload)
      unless properties[:correlation_id]
        error_message = "Message #{properties[:message_id]} dropped: #{return_info[:reply_text]} [#{return_info[:reply_code]}]"
        reply_queue.handle_reply MessageDropped.new(error_message, payload), properties[:message_id]
      else # a reply dropped - client reply queue probably does not exist any more
        logger.debug "Reply on message #{properties[:correlation_id]} dropped: #{return_info[:reply_text]} [#{return_info[:reply_code]}]"
      end
    rescue
      logger.error "Internal error (on_return): #{$!}"
      logger.error $!.backtrace.join("\n")
    end

    def create_channel_wrap(thread=Thread.current)
      raise ConnectionFailed.new("Channel already created for thread #{thread.object_id}") if @channel_pool[thread.object_id]
      raise ConnectionFailed.new("Unable to create channel. Connection lost.") unless @connection

      channel  = create_channel(@work_pool_size)
      exchange = create_exchange(channel)
      exchange.on_return(&method(:on_return))

      channel_wrap                    = ChannelWrap.new(channel, exchange)
      @channel_pool[thread.object_id] = channel_wrap

      channel_wrap
    rescue Bunny::PreconditionFailed => ex
      raise ConnectionFailed.new("Unable create exchange: '#{@exchange_name}': #{ex.message}")
    end

    def channel_wrap(thread=Thread.current)
      channel_wrap = @channel_pool[thread.object_id]
      if channel_wrap && channel_wrap.channel.active
        channel_wrap
      else
        @channel_pool.delete(thread.object_id) # ensure inactive channel s not cached
        create_channel_wrap(thread)
      end
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

      def self.load(name, config=nil)
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

        if defined?(Rails) && Rails.root
          config_path = Rails.root.join('config/rabbit.yml')
          if config_path.exist?
            rails_config = YAML.load_file(config_path)
            raise "Unexpected rabbit.yml: #{rails_config.inspect}, Hash expected." unless rails_config.is_a?(Hash)
            rails_config = rails_config.symbolize_keys
            unless rails_config[:host] # backward compatibility
              rails_config = rails_config[name.to_sym]
              raise "RabbitMQ '#{name}' configuration not set in rabbit.yml" unless rails_config
            else
              warn "DEPRECATION WARNING: rabbit.yml should define different configurations for Rails environments (like database.yml). Please update your configuration file: #{config_path}."
            end
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

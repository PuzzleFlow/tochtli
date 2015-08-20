require_relative 'common'

Tochtli.logger.progname = 'CLIENT'

module LogAnalyzer
  class Client < Tochtli::BaseClient
    def send_new_log(path)
      publish NewLog.new(path: path)
    end

    def react_on_events(client_id, severities, handler=nil, &block)
      handler = block unless handler
      severities = Array(severities)
      routing_keys = severities.map {|severity| "log.events.#{severity}" }
      Tochtli::ControllerManager.start EventsController,
                                       queue_name: "log_analyzer/events/#{client_id}", # custom queue name
                                       routing_keys: routing_keys, # make custom binding (only selected severities)
                                       env: { handler: handler }
    end

    def monitor_status(monitor=nil, &block)
      monitor = block unless monitor
      Tochtli::ControllerManager.start MonitorController, env: { monitor: monitor }
    end
  end

  protected

  class EventsController < Tochtli::BaseController
    on EventOccurred, :handle, routing_key: 'log.events.*'

    def handle
      handler.call(message.severity, message.timestamp, message.message)
    end

    protected

    def handler
      raise "Internal Error: handler not set for EventsController" unless env.has_key?(:handler)
      env[:handler]
    end
  end

  class MonitorController < Tochtli::BaseController
    bind 'log.status'

    self.queue_name        = '' # auto generate
    self.queue_durable     = false
    self.queue_exclusive   = true
    self.queue_auto_delete = true

    on CurrentStatus do
      monitor.call(message.to_hash)
    end

    protected

    def monitor
      raise "Internal Error: monitor not set for MonitorController" unless env.has_key?(:monitor)
      env[:monitor]
    end
  end
end

client = LogAnalyzer::Client.new
command = ARGV[0]

def hold
  puts 'Press Ctrl-C to stop...'
  sleep
end


case command
  when 's'
    client.send_new_log ARGV[1]
  when 'm'
    client.monitor_status {|status| p status }
    hold
  when 'c'
    client.react_on_events ARGV[1], [:fatal, :error], lambda {|severity, timestamp, message|
      puts "[#{timestamp}] Got #{severity}: #{message}"
    }
    hold
  else
    puts "Unknown command: #{command.inspect}"
    puts
    puts "Usage: bundle exec ruby client [command] [params]"
    puts
    puts "Commands:"
    puts "  s [path]      - send log from file to server"
    puts "  m             - start status monitor"
    puts "  c [client ID] - catch fatal and error events"
end


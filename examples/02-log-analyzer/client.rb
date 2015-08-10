require_relative 'common'

Tochtli.logger.progname = 'CLIENT'

module LogAnalyzer
  class Client < Tochtli::BaseClient
    def send_new_log(path)
      publish NewLog.new(path: path)
    end

    def react_on_events(severities, handler=nil, &block)
	    handler = block unless handler
			raise "Events handler already started" if EventsController.handler
      EventsController.handler = handler
      severities               = Array(severities)
      severities.each do |severity|
        routing_key = "log.events.#{severity}"
        EventsController.bind routing_key
        EventsController.on EventOccurred, :handle, routing_key: routing_key
      end
      Tochtli::ControllerManager.start EventsController
    end

    def monitor_status(monitor=nil, &block)
	    monitor = block unless monitor
      raise "Monitor already started" if MonitorController.monitor
      MonitorController.monitor = monitor
      Tochtli::ControllerManager.start MonitorController
    end
  end

  protected

  class EventsController < Tochtli::BaseController
    mattr_accessor :handler

    self.queue_name = '' # auto generate

    def handle
      self.class.handler.call(message.severity, message.timestamp, message.message)
    end
  end

  class MonitorController < Tochtli::BaseController
    mattr_accessor :monitor

    bind 'log.status'

    self.queue_name      = '' # auto generate
    self.queue_durable   = false
    self.queue_exclusive = true

    on CurrentStatus do
      self.class.monitor.call(message.to_hash)
    end
  end
end

Tochtli::ControllerManager.setup
client = LogAnalyzer::Client.new

case ARGV[0]
	when 's'
		client.send_new_log ARGV[1]
		exit
	when 'm'
		client.monitor_status {|status| p status }
	when 'n'
		client.react_on_events [:fatal, :error], lambda {|severity, timestamp, message|
			puts "[#{timestamp}] Got #{severity}: #{message}"
		}
end

puts 'Press Ctrl-C to stop monitor...'
sleep

require_relative 'common'

Tochtli.logger.progname = 'CLIENT'

module LogAnalyzer
  class Client < Tochtli::BaseClient
    def send_new_log(path)
      publish NewLog.new(path: path)
    end

    def react_on_events(severities, handler)
      raise "Events handler already started" if EventsController.handler
      EventsController.handler = handler
      severities               = Array(severities)
      severities.each do |severity|
        routing_key = "log.events.#{severity}"
        EventsController.bind routing_key
        EventsController.on EventOccurred, :handle, routing_key: routing_key
      end
      EventsController.start
    end

    def monitor_status(monitor)
      raise "Monitor already started" if MonitorController.handler
      MonitorController.monitor = monitor
      MonitorController.start
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
      self.class.monitor.call(message.errors, message.warnings, message.all, message.timestamp)
    end
  end
end

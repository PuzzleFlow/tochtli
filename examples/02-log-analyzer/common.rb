require 'bundler'
Bundler.require

Tochtli.logger = Logger.new('tochtli.log')

module LogAnalyzer
  MONITOR_EXCHANGE = 'log.notifications'

  class NewLog < Tochtli::Message
    route_to 'log.analyzer.new'

    attribute :path
  end

  class EventOccurred < Tochtli::Message
    route_to { "log.events.#{severity}" }

    attribute :severity
    attribute :timestamp, type: Time
    attribute :message
  end

  class CurrentStatus < Tochtli::Message
    route_to 'log.status'

    attribute :fatal, type: Integer, default: 0
    attribute :error, type: Integer, default: 0
    attribute :warn, type: Integer, default: 0
    attribute :info, type: Integer, default: 0
    attribute :debug, type: Integer, default: 0
    attribute :timestamp, Time
  end
end
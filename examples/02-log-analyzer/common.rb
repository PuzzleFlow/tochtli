require 'bundler'
Bundler.require

Tochtli.logger = Logger.new('tochtli.log')

module LogAnalyzer
  MONITOR_EXCHANGE = 'log.notifications'

  class NewLog < Tochtli::Message
    route_to 'log.analyzer.new'

    attribute :path, String
  end

  class EventOccurred < Tochtli::Message
    route_to lambda {|msg| "log.events.#{msg.severity}" }

    attribute :severity, String
    attribute :timestamp, Time
    attribute :message, String
  end

  class CurrentStatus < Tochtli::Message
    route_to 'log.status'

    attribute :fatal, Integer, default: 0
    attribute :error, Integer, default: 0
    attribute :warn, Integer, default: 0
    attribute :info, Integer, default: 0
    attribute :debug, Integer, default: 0
    attribute :timestamp, Time
  end
end
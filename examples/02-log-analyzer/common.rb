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

    attribute :errors, Integer
    attribute :warnings, Integer
    attribute :all, Integer
    attribute :timestamp, Time
  end
end
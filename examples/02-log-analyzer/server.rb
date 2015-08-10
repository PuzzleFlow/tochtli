require_relative 'common'

Thread.abort_on_exception = true

Tochtli.logger.progname = 'SERVER'

module LogAnalyzer

  class LogController < Tochtli::BaseController
    bind 'log.analyzer.*'

    on NewLog, :create

    cattr_accessor :monitor

    def self.start(queue_name=nil)
			super
			self.monitor = StatusMonitor.new(self.dispatcher.rabbit_connection)
			self.monitor.start
    end

    def create
      parser   = LogParser.new(message.path)
      notifier = EventNotifier.new(self.class.dispatcher.rabbit_connection)
      parser.each do |event|
        severity = event[:severity]
        notifier.notify event if EventNotifier.significant?(severity)
        self.monitor.note severity
      end
      notifier.wait_for_confirms
    end
  end

  class LogParser
    def initialize(path)
      @file = File.open(path, 'rb')
    end

    def each
      @file.each_line do |line|
        event = parse(line)
        yield event if event
      end
    end

    protected

    SEVERITY = {
            'F' => :fatal,
            'E' => :error,
            'W' => :warn,
            'I' => :info,
            'D' => :debug
    }

    def parse(line)
      # W, [2015-08-06T13:38:16.270700 #4140]  WARN -- : Sample warn
      severity = SEVERITY[line[0]]
      if severity
        time = Time.parse(line[4..29])
        message = line[49..-1]
        {
                severity: severity,
                timestamp: time,
                message: message
        }
      end
    end
  end

  class EventNotifier < Tochtli::BaseClient
		SIGNIFICANT_SEVERITIES = [:fatal, :error, :warn]

		def self.significant?(severity)
			SIGNIFICANT_SEVERITIES.include?(severity)
		end

    def notify(event)
      publish EventOccurred.new(event), mandatory: false
    end

    def update_status(status)
      publish CurrentStatus.new(status)
    end
  end

  class StatusMonitor
    include MonitorMixin

    def initialize(rabbit_connection)
      super()
      @notifier = EventNotifier.new(rabbit_connection)

      @status = Hash.new(0)
    end

    def start
      Thread.new(&method(:monitor))
    end

    def note(severity)
      synchronize do
        @status[severity] += 1
      end
    end

    def reset_status
      synchronize do
        status = @status
        @status = Hash.new(0)
        status
      end
    end

    protected

    def monitor
      loop do
        current_status = reset_status
        current_status[:timestamp] = Time.now
		    @notifier.update_status current_status
        sleep 10
      end
    end
  end
end

Tochtli::ControllerManager.setup
Tochtli::ControllerManager.start

trap('SIGINT') { exit }
at_exit { Tochtli::ControllerManager.stop }

puts 'Press Ctrl-C to stop worker...'
sleep

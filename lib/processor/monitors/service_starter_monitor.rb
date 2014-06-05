module Processor
	module Monitors
		class ServiceStarterMonitor < BaseMonitor
			def initialize(logger = nil)
				super
				report_info "Starting services..."
				logger = Logger.new(File.join(Rails.root, 'log/services.log'))
				ServiceBase.start_services nil, logger
			end
		end
	end
end

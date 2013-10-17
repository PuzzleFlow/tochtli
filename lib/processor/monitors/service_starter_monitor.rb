module Processor
	module Monitors
		class ServiceStarterMonitor < BaseMonitor
			def initialize(logger = nil)
				super
				report_info "Starting services..."
				ServiceBase.start_services nil, logger
			end
		end
	end
end

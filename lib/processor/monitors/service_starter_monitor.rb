module Processor
	module Monitors
		class ServiceStarterMonitor < BaseMonitor
			def initialize(logger = nil)
				super
				report_info "Starting services..."
				@logger = Logger.new(File.join(Rails.root, 'log/services.log'))
				ServiceBase.start_services nil, @logger
			end

			def run_single
				unless ServiceBase.services_running?
					report_info "Restarting services after termination..."
					ServiceBase.restart_services nil, @logger
				end
			end
		end
	end
end

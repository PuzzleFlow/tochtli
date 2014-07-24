module Processor
	module Monitors
		class ServiceStarterMonitor < BaseMonitor
			def initialize(logger = nil)
				super
				@logger = ServiceBase.logger

				report_info "Loading services..."
				ServiceBase.load_services

				report_info "Starting services..."
				@first_start = true
			rescue
				report_error "Unable to start services: #{$!} [#{$!.class}]"
				report_error $!.backtrace.join("\n")
			end

			def run_single
				unless ServiceBase.services_running?
					report_info "Restarting services after termination..." unless @first_start
					@first_start = false

					ServiceBase.restart_services
				end
			rescue
				report_error "Unable to restart services: #{$!} [#{$!.class}]"
				report_error $!.backtrace.join("\n")
			end
		end
	end
end

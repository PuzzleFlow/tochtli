module Processor
	module Monitors
		class ServiceStarterMonitor < BaseMonitor
			def initialize(logger = nil)
				super
				@logger = Logger.new(File.join(Rails.root, 'log/services.log'))
				@logger.level = ENV['RAILS_ENV']=='production' ? Logger::WARN : Logger::DEBUG
				@logger.formatter = CommonTools::StandardFormatter.new

				report_info "Loading services..."
				ServiceBase.load_services

				report_info "Starting services..."
			rescue
				report_error "Unable to start services: #{$!} [#{$!.class}]"
				report_error $!.backtrace.join("\n")
			end

			def run_single
				unless ServiceBase.services_running?
					report_info "Restarting services after termination..."
					ServiceBase.restart_services nil, @logger
				end
			rescue
				report_error "Unable to restart services: #{$!} [#{$!.class}]"
				report_error $!.backtrace.join("\n")
			end
		end
	end
end

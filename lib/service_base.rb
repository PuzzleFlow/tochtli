require 'service_base/engine' if defined?(::Rails)
require 'active_support/core_ext'
require 'bunny'

module ServiceBase
	autoload :RabbitConnection, 'service_base/rabbit_connection'
	autoload :Configuration, 'service_base/configuration'
	autoload :BaseController, 'service_base/base_controller'
	autoload :ControllerManager, 'service_base/controller_manager'
	autoload :Message, 'service_base/message'
	autoload :MessageMap, 'service_base/message_map'
	autoload :ReplyQueue, 'service_base/reply_queue'
	autoload :RabbitClient, 'service_base/rabbit_client'
	autoload :ClientProxy, 'service_base/client_proxy'
	autoload :AsyncClientProxy, 'service_base/async_client_proxy'
	autoload :Test, 'service_base/test'
	autoload :ServiceCache, 'service_base/service_cache'

	class InvalidMessageError < StandardError
		def initialize(message, service_message)
			super(message)
			@service_message = service_message
		end
	end

	class << self
		# Global logger for services (default: RAILS_ROOT/log/services.log)
		attr_writer :logger

		def logger
			unless @logger
				@logger = Logger.new(File.join(Rails.root, 'log/services.log'))
				@logger.level = ENV['RAILS_ENV']=='production' ? Logger::WARN : Logger::DEBUG
				if defined?(CommonTools) # $%$%!$%!#!$%#$!%$%^
					# TODO: move CommonTools::StandardFormatter to COMMON tools

					@logger.formatter = CommonTools::StandardFormatter.new
				end
			end
			@logger
		end

		# Should be invoked only once
		def load_services
			eager_load_service_messages
			eager_load_service_controllers
		end

		def start_services(rabbit_config=nil, logger=nil)
			ControllerManager.start(rabbit_config, logger)
			true
		rescue
			if logger
				logger.error "Error during service start"
				logger.error "#{$!.class}: #{$!}"
				logger.error $!.backtrace.join("\n")
			end
			false
		end

		def stop_services(logger=nil)
			ControllerManager.stop
			true
		rescue
			if logger
				logger.error "Error during service stop"
				logger.error "#{$!.class}: #{$!}"
				logger.error $!.backtrace.join("\n")
			end
			false
		end

		def services_running?
			ControllerManager.running?
		end

		def restart_services(rabbit_config=nil, logger=nil)
			ControllerManager.stop if ControllerManager.running?
			ControllerManager.start(rabbit_config, logger)
			true
		rescue
			if logger
				logger.error "Error during service restart"
				logger.error "#{$!.class}: #{$!}"
				logger.error $!.backtrace.join("\n")
			end
			false
		end

		def eager_load_service_messages
			Rails::Engine::Railties.engines.each do |engine|
				next unless engine.paths["service/messages"]
				engine.paths["service/messages"].existent.each do |load_path|
					Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
						require file
					end
				end
			end
		end

		def eager_load_service_controllers
			Rails::Engine::Railties.engines.each do |engine|
				next unless engine.paths["service/controllers"]
				engine.paths["service/controllers"].existent.each do |load_path|
					Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
						require file
					end
				end
			end
		end

		def eager_load_service_files(service_path, type)
			Dir.glob("#{service_path}/service/#{type}/**/*.rb").sort.each do |file|
				require file
			end
		end
	end
end

require File.expand_path('../boot', __FILE__)

require 'rails/all'

Bundler.require

require 'service_base'

module Dummy
	class Application < Rails::Application
		# Set dummy app root
		config.root = File.expand_path('../..', __FILE__)

		config.eager_load = false
		config.encoding = "utf-8"
		config.filter_parameters += [:password]
		config.active_support.escape_html_entities_in_json = true
		config.active_record.schema_format = :sql
		config.assets.enabled = true
		config.assets.version = '1.0'
		config.cache_classes = true
		config.serve_static_assets = true
		config.static_cache_control = "public, max-age=3600"
		config.whiny_nils = true
		config.consider_all_requests_local = true
		config.action_controller.perform_caching = false
		config.action_dispatch.show_exceptions = false
		config.action_controller.allow_forgery_protection = false
		config.action_mailer.delivery_method = :test
		config.active_support.deprecation = :stderr
		config.secret_token = 'efc39d860d9d26146e6546fc69b12c014f98785e08a8099174583af0a04a27774604060f591678aef27c491f9d00792a00884a92bb35e4ca122d0cbeddd4ea98'
	end
end



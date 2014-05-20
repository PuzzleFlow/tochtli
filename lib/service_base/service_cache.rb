module ServiceBase
	class ServiceCache
		attr_reader :store

		def self.create
			require 'active_support/cache/dalli_store'
			new.store
		end

		def initialize
			if config[:host]
				@store = ActiveSupport::Cache::DalliStore.new(config[:host])
			else
				@store = ActiveSupport::Cache::DalliStore.new
			end
		end

		def config
			config_from_file || {}
		end

		def config_from_file
			path = File.join(Rails.root, 'config', 'memcache.yml')
			if File.exist?(path)
				return YAML.load_file(path).symbolize_keys
			end
			nil
		end
	end
end
require 'active_support/cache/dalli_store'

module ServiceBase
	class ServiceCache
		attr_reader :store

		def self.create
			new.store
		end

		def initialize
			if defined?(Rails)
				@store = Rails.cache
			else
				defaults = {
					value_max_bytes: 4194304, # 4MB as max value, remember to configure memcache with -I
					compress: true
				}
				host = config.fetch(:host, "localhost:11211")
				opts = config.fetch(:opts, {}).merge(defaults)

				@store = ActiveSupport::Cache::DalliStore.new(host, opts)
			end
		end

	end
end
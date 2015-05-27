require 'active_support/cache/dalli_store'

module ServiceBase
	class ServiceCache
		attr_reader :store

		def self.store
			@cache ||= new
			@cache.store
		end

		def initialize
			if defined?(Rails)
				@store = Rails.cache
			else
				defaults = {
					value_max_bytes: 4194304, # 4MB as max value, remember to configure memcache with -I
					compress: true
				}
				@store = ActiveSupport::Cache::DalliStore.new(nil, defaults)
			end
		end

	end
end
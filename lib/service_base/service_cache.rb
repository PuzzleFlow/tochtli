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
				@store = ActiveSupport::Cache::DalliStore.new
			end
		end

	end
end
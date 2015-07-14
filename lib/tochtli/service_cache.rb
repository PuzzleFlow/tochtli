require 'dalli' unless defined?(Rails)

module Tochtli
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
            compress:        true
        }
        @store   = Dalli::Client.new(nil, defaults)
      end
    end

  end
end
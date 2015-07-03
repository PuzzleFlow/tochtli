require 'mini_cache'

module Tochtli
  module Test
    # a simple proxy to replicate ActiveSupport cache interface using mini store
    class MemoryCache
      attr_reader :store

      def initialize
        @store = MiniCache::Store.new
      end

      def write(name, value)
        store.set(name, value)
      end

      def read(name)
        store.get(name)
      end
    end
  end
end
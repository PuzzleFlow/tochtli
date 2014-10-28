module ServiceBase
	module Test
		class Controller < ServiceBase::Test::TestCase
			class_attribute :controller_class

			def self.tests(controller_class)
				self.controller_class = controller_class
			end

			setup do
				@cache = ActiveSupport::Cache::MemoryStore.new
				begin
					@configuration_store = ServiceBase::Configuration::ActiveRecordStore.new
				rescue LoadError
					# ignore lack of pg_hstore
				end
				@logger = ServiceBase.logger
				@controller = self.controller_class.new(@connection, @cache, @configuration_store, @logger)
			end

		end
	end
end

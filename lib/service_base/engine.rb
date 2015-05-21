require 'hoe/puzzleflow/engine_support'

module ServiceBase
	class Engine < ::Rails::Engine
		include Hoe::PuzzleFlow::EngineSupport

		initializer :eager_load_messages, :before => :bootstrap_hook do
			ServiceBase.eager_load_service_messages
		end

		initializer :use_active_record_connection_release do
			ActiveSupport.on_load(:active_record) do
				ServiceBase.application.middlewares.use ServiceBase::ActiveRecordConnectionCleaner
			end
		end

		add_engine_migrations

	end
end
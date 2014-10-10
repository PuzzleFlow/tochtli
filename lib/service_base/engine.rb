require 'hoe/puzzleflow/engine_support'

module ServiceBase
	class Engine < ::Rails::Engine
		include Hoe::PuzzleFlow::EngineSupport

		initializer :eager_load_messages, :before => :bootstrap_hook do
			ServiceBase.eager_load_service_messages
		end

		add_engine_migrations

	end
end
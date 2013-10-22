module ServiceBase
	class Engine < ::Rails::Engine

		initializer :add_service_migrations do |app|
			app.paths["db/migrate"] += config.paths["db/migrate"].map { |p| File.expand_path(p, config.root) }
		end

		initializer :eager_load_messages, :before => :bootstrap_hook do
			ServiceBase.eager_load_service_messages
		end

	end
end
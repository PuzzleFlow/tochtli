module ServiceBase
	class Engine < ::Rails::Engine

		Rails.application.paths["db/migrate"].concat config.paths["db/migrate"].map { |p| File.expand_path(p, config.root) }

		initializer :eager_load_messages, :before => :bootstrap_hook do
			ServiceBase.eager_load_service_messages
		end

	end
end
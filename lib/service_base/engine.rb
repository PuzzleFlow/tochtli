module ServiceBase
	class Engine < ::Rails::Engine

		initializer :eager_load_messages, :before => :bootstrap_hook do
			ServiceBase.preload_service_messages
		end

	end
end
module Tochtli
  class Engine < ::Rails::Engine

    initializer :eager_load_messages, :before => :bootstrap_hook do
      Tochtli.eager_load_service_messages
    end

    initializer :use_active_record_connection_release do
      ActiveSupport.on_load(:active_record) do
        Tochtli.application.middlewares.use Tochtli::ActiveRecordConnectionCleaner
      end
    end

  end
end
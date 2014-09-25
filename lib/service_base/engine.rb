module ServiceBase
	class Engine < ::Rails::Engine

		module Support
			extend ActiveSupport::Concern

			included do
				class_eval do
					def self.add_engine_migrations
						rake_tasks do
							namespace :db do
								namespace railtie_name do
									namespace :add do
										desc "Add migration paths from #{railtie_name} to application migration paths"
										task :migrations do
											# Skip if working with current engine, would be added by railties task
											unless defined?(ENGINE_PATH) && ENGINE_PATH == root.to_s
												if ActiveRecord.const_defined?(:Tasks) # Rails 4.1
													ActiveRecord::Tasks::DatabaseTasks.migrations_paths += config.paths["db/migrate"].to_a
												else
													ActiveRecord::Migrator.migrations_paths += config.paths["db/migrate"].to_a
												end
											end
										end
									end
								end
								task :load_config => "db:#{railtie_name}:add:migrations"
							end
						end
					end
				end
			end
		end

		include ServiceBase::Engine::Support

		initializer :eager_load_messages, :before => :bootstrap_hook do
			ServiceBase.eager_load_service_messages
		end

		add_engine_migrations

	end
end
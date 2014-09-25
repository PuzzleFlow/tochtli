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
											Rails.application.paths["db/migrate"].concat config.paths["db/migrate"].map { |p| File.expand_path(p, config.root) }
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
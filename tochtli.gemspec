# -*- encoding: utf-8 -*-
# stub: tochtli 0.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "tochtli"
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.4") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["PuzzleFlow Team", "Rafa\u{142} Bigaj"]
  s.date = "2015-05-28"
  s.description = "The base components used by services' implementation."
  s.email = ["support@puzzleflow.com", "rafal.bigaj@puzzleflow.com"]
  s.extra_rdoc_files = ["History.md", "README.md"]
  s.files = [".gemtest", ".gitignore", "Gemfile", "History.md", "README.md", "Rakefile", "db/migrate/20131017134818_create_configuration_store.rb", "lib/tochtli.rb", "lib/tochtli/active_record_connection_cleaner.rb", "lib/tochtli/application.rb", "lib/tochtli/base_client.rb", "lib/tochtli/base_controller.rb", "lib/tochtli/client_proxy.rb", "lib/tochtli/configuration.rb", "lib/tochtli/controller_manager.rb", "lib/tochtli/engine.rb", "lib/tochtli/message.rb", "lib/tochtli/message_map.rb", "lib/tochtli/rabbit_client.rb", "lib/tochtli/rabbit_connection.rb", "lib/tochtli/reply_queue.rb", "lib/tochtli/service_cache.rb", "lib/tochtli/test.rb", "lib/tochtli/test/client.rb", "lib/tochtli/test/controller.rb", "lib/tochtli/test/integration.rb", "lib/tochtli/test/test_case.rb", "lib/tochtli/version.rb", "tochtli.gemspec", "test/base_client_test.rb", "test/configuration_store_test.rb", "test/controller_functional_test.rb", "test/controller_integration_test.rb", "test/controller_manager_test.rb", "test/dummy/Rakefile", "test/dummy/config/application.rb", "test/dummy/config/boot.rb", "test/dummy/config/environment.rb", "test/dummy/db/.gitkeep", "test/dummy/log/.gitkeep", "test/message_test.rb", "test/rabbit_client_test.rb", "test/rabbit_connection_test.rb", "test/test_helper.rb"]
  s.homepage = "https://git.puzzleflow.com:puzzleflow/tochtli"
  s.licenses = ["PuzzleFlow"]
  s.rdoc_options = ["--main", "README.md"]
  s.rubygems_version = "2.4.5"
  s.summary = "Tochtli a core components for SOA"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rails>, [">= 3.2.15"])
      s.add_runtime_dependency(%q<bunny>, [">= 1.7.0"])
      s.add_runtime_dependency(%q<dalli>, ["~> 2.6.4"])
      s.add_runtime_dependency(%q<hoe-puzzleflow>, ["~> 0.1.6"])
      s.add_development_dependency(%q<geminabox>, ["~> 0.12.4"])
      s.add_development_dependency(%q<hoe>, ["~> 3.7"])
      s.add_development_dependency(%q<hoe-git>, ["~> 1.6"])
      s.add_development_dependency(%q<rdoc>, [">= 3.4"])
      s.add_development_dependency(%q<pg>, [">= 0.17.0"])
      s.add_development_dependency(%q<pg-hstore>, ["~> 1.2.0"])
      s.add_development_dependency(%q<eventmachine>, ["~> 1.0.0"])
      s.add_development_dependency(%q<minitest>, [">= 4.7.5"])
    else
      s.add_dependency(%q<rails>, [">= 3.2.15"])
      s.add_dependency(%q<bunny>, [">= 1.7.0"])
      s.add_dependency(%q<dalli>, ["~> 2.6.4"])
      s.add_dependency(%q<hoe-puzzleflow>, ["~> 0.1.6"])
      s.add_dependency(%q<geminabox>, ["~> 0.12.4"])
      s.add_dependency(%q<hoe>, ["~> 3.7"])
      s.add_dependency(%q<hoe-git>, ["~> 1.6"])
      s.add_dependency(%q<rdoc>, [">= 3.4"])
      s.add_dependency(%q<pg>, [">= 0.17.0"])
      s.add_dependency(%q<pg-hstore>, ["~> 1.2.0"])
      s.add_dependency(%q<eventmachine>, ["~> 1.0.0"])
      s.add_dependency(%q<minitest>, [">= 4.7.5"])
    end
  else
    s.add_dependency(%q<rails>, [">= 3.2.15"])
    s.add_dependency(%q<bunny>, [">= 1.7.0"])
    s.add_dependency(%q<dalli>, ["~> 2.6.4"])
    s.add_dependency(%q<hoe-puzzleflow>, ["~> 0.1.6"])
    s.add_dependency(%q<geminabox>, ["~> 0.12.4"])
    s.add_dependency(%q<hoe>, ["~> 3.7"])
    s.add_dependency(%q<hoe-git>, ["~> 1.6"])
    s.add_dependency(%q<rdoc>, [">= 3.4"])
    s.add_dependency(%q<pg>, [">= 0.17.0"])
    s.add_dependency(%q<pg-hstore>, ["~> 1.2.0"])
    s.add_dependency(%q<eventmachine>, ["~> 1.0.0"])
    s.add_dependency(%q<minitest>, [">= 4.7.5"])
  end
end

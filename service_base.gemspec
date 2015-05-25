# -*- encoding: utf-8 -*-
# stub: service_base 0.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "service_base"
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.4") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["PuzzleFlow Team", "Rafa\xC5\x82 Bigaj"]
  s.date = "2015-05-25"
  s.description = "The base components used by services' implementation."
  s.email = ["support@puzzleflow.com", "rafal.bigaj@puzzleflow.com"]
  s.extra_rdoc_files = ["History.md", "README.md"]
  s.files = [".gemtest", ".gitignore", "Gemfile", "History.md", "README.md", "Rakefile", "db/migrate/20131017134818_create_configuration_store.rb", "lib/service_base.rb", "lib/service_base/active_record_connection_cleaner.rb", "lib/service_base/application.rb", "lib/service_base/base_client.rb", "lib/service_base/base_controller.rb", "lib/service_base/client_proxy.rb", "lib/service_base/configuration.rb", "lib/service_base/controller_manager.rb", "lib/service_base/engine.rb", "lib/service_base/message.rb", "lib/service_base/message_map.rb", "lib/service_base/rabbit_client.rb", "lib/service_base/rabbit_connection.rb", "lib/service_base/reply_queue.rb", "lib/service_base/service_cache.rb", "lib/service_base/test.rb", "lib/service_base/test/client.rb", "lib/service_base/test/controller.rb", "lib/service_base/test/integration.rb", "lib/service_base/test/test_case.rb", "lib/service_base/version.rb", "service_base.gemspec", "test/base_client_test.rb", "test/configuration_store_test.rb", "test/controller_functional_test.rb", "test/controller_integration_test.rb", "test/dummy/Rakefile", "test/dummy/config/application.rb", "test/dummy/config/boot.rb", "test/dummy/config/environment.rb", "test/dummy/db/.gitkeep", "test/dummy/log/.gitkeep", "test/message_test.rb", "test/rabbit_client_test.rb", "test/rabbit_connection_test.rb", "test/test_helper.rb"]
  s.homepage = "https://git.puzzleflow.com:puzzleflow/service_base"
  s.licenses = ["PuzzleFlow"]
  s.rdoc_options = ["--main", "README.md"]
  s.rubygems_version = "2.4.6"
  s.summary = "ServiceBase a core components for SOA"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rails>, [">= 3.2.15"])
      s.add_runtime_dependency(%q<bunny>, [">= 1.3.1"])
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
      s.add_development_dependency(%q<test-unit>, [">= 3.0.9"])
    else
      s.add_dependency(%q<rails>, [">= 3.2.15"])
      s.add_dependency(%q<bunny>, [">= 1.3.1"])
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
      s.add_dependency(%q<test-unit>, [">= 3.0.9"])
    end
  else
    s.add_dependency(%q<rails>, [">= 3.2.15"])
    s.add_dependency(%q<bunny>, [">= 1.3.1"])
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
    s.add_dependency(%q<test-unit>, [">= 3.0.9"])
  end
end

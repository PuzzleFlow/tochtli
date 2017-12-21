# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: tochtli 0.5.1 ruby lib

Gem::Specification.new do |s|
  s.name = "tochtli"
  s.version = "0.5.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Rafal Bigaj"]
  s.date = "2017-12-21"
  s.description = "Lightweight framework for service oriented applications based on bunny (RabbitMQ)"
  s.email = "rafal.bigaj@puzzleflow.com"
  s.extra_rdoc_files = [
    "README.md"
  ]
  s.files = [
    ".travis.yml",
    "Gemfile",
    "History.md",
    "Procfile.example",
    "README.md",
    "Rakefile",
    "VERSION",
    "assets/communication.png",
    "assets/layers.png",
    "examples/01-screencap-service/Gemfile",
    "examples/01-screencap-service/README.md",
    "examples/01-screencap-service/client.rb",
    "examples/01-screencap-service/common.rb",
    "examples/01-screencap-service/server.rb",
    "examples/02-log-analyzer/Gemfile",
    "examples/02-log-analyzer/README.md",
    "examples/02-log-analyzer/client.rb",
    "examples/02-log-analyzer/common.rb",
    "examples/02-log-analyzer/sample.log",
    "examples/02-log-analyzer/server.rb",
    "lib/tochtli.rb",
    "lib/tochtli/active_record_connection_cleaner.rb",
    "lib/tochtli/application.rb",
    "lib/tochtli/base_client.rb",
    "lib/tochtli/base_controller.rb",
    "lib/tochtli/controller_manager.rb",
    "lib/tochtli/engine.rb",
    "lib/tochtli/message.rb",
    "lib/tochtli/rabbit_client.rb",
    "lib/tochtli/rabbit_connection.rb",
    "lib/tochtli/reply_queue.rb",
    "lib/tochtli/simple_validation.rb",
    "lib/tochtli/test.rb",
    "lib/tochtli/test/client.rb",
    "lib/tochtli/test/controller.rb",
    "lib/tochtli/test/integration.rb",
    "lib/tochtli/test/memory_cache.rb",
    "lib/tochtli/test/test_case.rb",
    "lib/tochtli/test/test_unit.rb",
    "lib/tochtli/version.rb",
    "test/base_client_test.rb",
    "test/controller_functional_test.rb",
    "test/controller_integration_test.rb",
    "test/controller_manager_test.rb",
    "test/dummy/Rakefile",
    "test/dummy/config/application.rb",
    "test/dummy/config/boot.rb",
    "test/dummy/config/database.yml",
    "test/dummy/config/environment.rb",
    "test/dummy/config/rabbit.yml",
    "test/dummy/db/.gitkeep",
    "test/dummy/log/.gitkeep",
    "test/key_matcher_test.rb",
    "test/log/.gitkeep",
    "test/message_test.rb",
    "test/rabbit_client_test.rb",
    "test/rabbit_connection_test.rb",
    "test/test_helper.rb",
    "test/version_test.rb",
    "tochtli.gemspec"
  ]
  s.homepage = "http://github.com/puzzleflow/tochtli"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.5.1"
  s.summary = "Tochtli a core components for SOA"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<bunny>, ["~> 2.3.0"])
      s.add_runtime_dependency(%q<uber>, [">= 0.0.14"])
      s.add_runtime_dependency(%q<virtus>, [">= 0"])
      s.add_runtime_dependency(%q<facets>, [">= 0"])
      s.add_runtime_dependency(%q<hooks>, [">= 0"])
      s.add_development_dependency(%q<dalli>, ["~> 2.6.4"])
      s.add_development_dependency(%q<jeweler>, ["~> 2.3.7"])
      s.add_development_dependency(%q<mini_cache>, [">= 0"])
      s.add_development_dependency(%q<yard>, ["~> 0.9.11"])
      s.add_development_dependency(%q<minitest>, [">= 4.7.5"])
      s.add_development_dependency(%q<minitest-reporters>, [">= 0.5.0"])
      s.add_development_dependency(%q<foreman>, [">= 0"])
    else
      s.add_dependency(%q<bunny>, ["~> 2.3.0"])
      s.add_dependency(%q<uber>, [">= 0.0.14"])
      s.add_dependency(%q<virtus>, [">= 0"])
      s.add_dependency(%q<facets>, [">= 0"])
      s.add_dependency(%q<hooks>, [">= 0"])
      s.add_dependency(%q<dalli>, ["~> 2.6.4"])
      s.add_dependency(%q<jeweler>, ["~> 2.3.7"])
      s.add_dependency(%q<mini_cache>, [">= 0"])
      s.add_dependency(%q<yard>, ["~> 0.9.11"])
      s.add_dependency(%q<minitest>, [">= 4.7.5"])
      s.add_dependency(%q<minitest-reporters>, [">= 0.5.0"])
      s.add_dependency(%q<foreman>, [">= 0"])
    end
  else
    s.add_dependency(%q<bunny>, ["~> 2.3.0"])
    s.add_dependency(%q<uber>, [">= 0.0.14"])
    s.add_dependency(%q<virtus>, [">= 0"])
    s.add_dependency(%q<facets>, [">= 0"])
    s.add_dependency(%q<hooks>, [">= 0"])
    s.add_dependency(%q<dalli>, ["~> 2.6.4"])
    s.add_dependency(%q<jeweler>, ["~> 2.3.7"])
    s.add_dependency(%q<mini_cache>, [">= 0"])
    s.add_dependency(%q<yard>, ["~> 0.9.11"])
    s.add_dependency(%q<minitest>, [">= 4.7.5"])
    s.add_dependency(%q<minitest-reporters>, [">= 0.5.0"])
    s.add_dependency(%q<foreman>, [">= 0"])
  end
end


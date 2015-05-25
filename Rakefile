# encoding: utf-8
#!/usr/bin/env rake

begin
	require 'hoe/puzzleflow'
rescue LoadError
	abort "This Rakefile requires hoe-puzzleflow (gem install hoe-puzzleflow --source https://gems.puzzleflow.com)"
end

Hoe::PuzzleFlow.setup_plugins
Hoe.plugin :richyard

require './lib/service_base/version'

Hoe::NoManifest.spec 'service_base' do
	self.version = ServiceBase::VERSION
	self.testlib = :none

	self.summary = 'ServiceBase a core components for SOA'
	self.description = "The base components used by services' implementation."

	dependency "rails", ">= 3.2.15"
	dependency "bunny", ">= 1.3.1"
	dependency "dalli", "~> 2.6.4"
	dependency "hoe-puzzleflow", "~> 0.1.6"
	dependency "pg", ">= 0.17.0", :development
	dependency "pg-hstore", "~> 1.2.0", :development
	dependency "eventmachine", "~> 1.0.0", :development
	dependency "minitest", ">= 4.7.5", :development
	dependency 'test-unit', ">= 3.0.9", :development

	developer 'Rafał Bigaj', 'rafal.bigaj@puzzleflow.com'
	license 'PuzzleFlow'
end

Hoe::PuzzleFlow.setup_dummy_application
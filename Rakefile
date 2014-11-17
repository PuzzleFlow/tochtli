#!/usr/bin/env rake

begin
	require 'hoe/puzzleflow'
rescue LoadError
	abort "This Rakefile requires hoe-puzzleflow (gem install hoe-puzzleflow --source https://gems.puzzleflow.com)"
end

Hoe::PuzzleFlow.setup_plugins

require './lib/service_base/version'

Hoe.spec 'service_base' do
	self.version = ServiceBase::VERSION
	self.testlib = :none

	dependency "rails", ">= 3.2.15"
	dependency "bunny", ">= 1.3.1"
	dependency "dalli", "~> 2.6.4"
	dependency "hoe-puzzleflow", "~> 0.1.6"
	dependency "pg", "0.17.0", :development
	dependency "pg-hstore", "~> 1.2.0", :development
	dependency "eventmachine", "~> 1.0.0", :development
	dependency "minitest", ">= 4.7.5", :development

	license 'PuzzleFlow'
end

Hoe::PuzzleFlow.setup_dummy_application
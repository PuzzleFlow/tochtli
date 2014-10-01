#!/usr/bin/env rake

ENV['RUBY_FLAGS'] = '-I.' # do not show warnings (default is '-w -I...')- bunny is full of unused variables

begin
	require 'hoe'
	require 'hoe/puzzleflow'
rescue LoadError
	abort "This Rakefile requires hoe-puzzleflow (gem install hoe-puzzleflow --source https://gems.puzzleflow.com)"
end

# Set up Hoe plugins
Hoe.plugin :geminabox
Hoe.plugin :git
Hoe.plugin :puzzleflow

require './lib/service_base/version'

Hoe.spec 'service_base' do
	self.version = ServiceBase::VERSION
	self.testlib = :testunit

	dependency "rails", ">= 3.2.15"
	dependency "bunny", ">= 1.3.1"
	dependency "dalli", "~> 2.6.4"
	dependency "hoe-puzzleflow", "~> 0.1.4", :development
	dependency "pg", "0.17.0", :development
	dependency "pg-hstore", "~> 1.2.0", :development
	dependency "eventmachine", "~> 1.0.0", :development
	dependency "test-unit", ">= 2.1.2", :development

	license 'PuzzleFlow'
end

Hoe::PuzzleFlow.setup_dummy_application
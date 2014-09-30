#!/usr/bin/env rake

ENV['RUBY_FLAGS'] = '-I.' # do not show warnings (default is '-w -I...')- bunny is full of unused variables

begin
	require 'hoe'
rescue LoadError
	abort "This Rakefile requires hoe (gem install hoe)"
end

# Set up Hoe plugins
Hoe.plugin :gemspec
Hoe.plugin :geminabox
Hoe.plugin :git

Hoe.spec 'service_base' do
	developer 'PuzzleFlow Team', 'support@puzzleflow.com'

	self.group_name = 'puzzleflow'
	self.geminabox_server = 'https://gems.puzzleflow.com'
	self.testlib = :testunit

	require_rubygems_version '>= 1.4'

	dependency "rails", ">= 3.2.15"
	dependency "bunny", ">= 1.3.1"
	dependency "dalli", "~> 2.6.4"
	dependency "hoe", "~> 3.7.1", :development
	dependency 'hoe-gemspec', '~> 1.0.0', :development
	dependency 'geminabox', '~> 0.12.4', :development
	dependency 'hoe-geminabox', '~> 0.3.1', :development
	dependency 'hoe-git', '~> 1.6.0', :development
	dependency "pg", "0.17.0", :development
	dependency "pg-hstore", "~> 1.2.0", :development
	dependency "eventmachine", "~> 1.0.0", :development
	dependency "test-unit", ">= 2.1.2", :development

	license "MIT"
end

# Before loading Gemfile we need to have up-to-date gemspec.
Rake::Task['gem:spec'].invoke

require 'bundler/setup'

# Setup Rails engine tasks

APP_RAKEFILE = File.expand_path("../test/dummy/Rakefile", __FILE__)
load 'rails/tasks/engine.rake'

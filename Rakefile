#!/usr/bin/env rake
begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

# Bundler setup fix
# Bundler adds "-Ipath" option which does not work when path contains space
# Fix the path by adding ""
if ENV['RUBYOPT'] =~ /^(.*)-I(.+) -rbundler\/setup(.*)$/
	ENV['RUBYOPT'] = %Q(#{$1}"-I#{$2}" -rbundler/setup#{$3})
end

begin
	require 'hoe'
rescue LoadError
	abort "This Rakefile requires hoe (gem install hoe)"
end

# Set up Hoe plugins
Hoe.plugin :bundler
Hoe.plugin :git
Hoe.plugin :geminabox

Hoe.spec 'service_base' do
	developer 'PuzzleFlow Team', 'support@puzzleflow.com'

	self.group_name = 'puzzleflow'
	self.geminabox_server = 'https://gems.puzzleflow.com'

	require_rubygems_version '>= 1.4'

	dependency "rails", ">= 3.2.15"
	dependency "bunny", ">= 1.3.1"
	dependency "dalli", "~> 2.6.4"
	dependency "hoe", "~> 3.7.1", :development
	dependency "pg", "0.17.0", :development
	dependency "pg-hstore", "~> 1.2.0", :development
	dependency "eventmachine", "~> 1.0.0", :development

	license "MIT"
end

begin
  require 'rdoc/task'
rescue LoadError
  require 'rdoc/rdoc'
  require 'rake/rdoctask'
  RDoc::Task = Rake::RDocTask
end

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'ServiceBase'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

APP_RAKEFILE = File.expand_path("../test/dummy/Rakefile", __FILE__)
load 'rails/tasks/engine.rake'

Bundler::GemHelper.install_tasks

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end


task :default => :test

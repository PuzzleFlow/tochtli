# encoding: utf-8
#!/usr/bin/env rake

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'rake/testtask'
require 'jeweler'
require 'yard'

Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name        = "tochtli"
  gem.homepage    = "http://github.com/puzzleflow/tochtli"
  gem.license     = "MIT"
  gem.summary     = %Q{Tochtli a core components for SOA}
  gem.description = %Q{Lightweight framework for service oriented applications based on bunny (RabbitMQ)}
  gem.email       = "rafal.bigaj@puzzleflow.com"
  gem.authors     = ["Rafal Bigaj"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

desc "Code coverage detail"
task :simplecov do
  ENV['COVERAGE'] = "true"
  Rake::Task['test'].execute
end

task :default => :test

YARD::Rake::YardocTask.new do |t|
  t.files         = ['lib/**/*.rb', 'README*'] # optional
  t.options       = ['--any', '--extra', '--opts'] # optional
  t.stats_options = ['--list-undoc'] # optional
end

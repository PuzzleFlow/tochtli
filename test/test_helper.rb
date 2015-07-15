require 'rubygems'
require 'bundler'
Bundler.require(:default, :development, :test)

$: << File.expand_path('../../lib', __FILE__)

require 'tochtli'
require 'minitest/autorun'

Tochtli.logger = Logger.new(File.join(File.dirname(__FILE__), 'test.log'))
Tochtli.cache = MiniCache::Store.new

if ENV['RAILS_VER']
  # Configure Rails Environment
  ENV["RAILS_ENV"] = "test"

  require File.expand_path("../dummy/config/environment.rb", __FILE__)
  require 'rails/test_help'
  require 'minitest/rails'

  Tochtli.load_services

  Rails.backtrace_cleaner.remove_silencers!

  # Load fixtures from the engine
  if ActiveSupport::TestCase.method_defined?(:fixture_path=)
    ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
  end
end

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
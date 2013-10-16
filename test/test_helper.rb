# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

SOLUTION_NAME = 'basic' unless defined?(SOLUTION_NAME)
require File.expand_path('../../../plugins/common_tools/test/common_test_helper', File.dirname(__FILE__))

ServiceBase.preload_service_messages
ServiceBase.preload_service_controllers

Rails.backtrace_cleaner.remove_silencers!

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

# Load fixtures from the engine
if ActiveSupport::TestCase.method_defined?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
end

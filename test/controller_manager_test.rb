require_relative 'test_helper'

Thread.abort_on_exception = true

class ControllerManagerTest < Tochtli::Test::TestCase
  class FirstController < Tochtli::BaseController
  end

  class SecondController < Tochtli::BaseController
  end

  class ThirdController < Tochtli::BaseController
  end

  setup do
    @logger       = Logger.new(STDERR)
    @logger.level = Logger::WARN
  end

  teardown do
    Tochtli::ControllerManager.stop
  end

  test 'start single controller' do
    Tochtli::ControllerManager.start(FirstController, connection: @connection, logger: @logger)
    assert FirstController.started?
    refute SecondController.started?
    refute ThirdController.started?
  end

  test 'start selected controllers' do
    Tochtli::ControllerManager.start(FirstController, ThirdController, connection: @connection, logger: @logger)
    assert FirstController.started?
    refute SecondController.started?
    assert ThirdController.started?
  end

  test 'start all controllers' do
    Tochtli::ControllerManager.start(:all, connection: @connection, logger: @logger)
    assert FirstController.started?
    assert SecondController.started?
    assert ThirdController.started?
  end

  test 'restart only active controllers' do
    Tochtli::ControllerManager.start(FirstController, SecondController, connection: @connection, logger: @logger)
    Tochtli::ControllerManager.restart(connection: @connection, logger: @logger)
    assert FirstController.started?
    assert SecondController.started?
    refute ThirdController.started?
  end

  test 'state monitor' do
    Tochtli::ControllerManager.start(FirstController, connection: @connection, logger: @logger)

  end
end

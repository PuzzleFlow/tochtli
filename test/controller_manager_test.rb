require_relative 'test_helper'

Thread.abort_on_exception = true

class ControllerManagerTest < Minitest::Test
  include Tochtli::Test::Helpers
  
  class FirstController < Tochtli::BaseController
  end

  class SecondController < Tochtli::BaseController
  end

  class ThirdController < Tochtli::BaseController
  end

  def setup
    @logger       = Logger.new(STDERR)
    @logger.level = Logger::WARN
  end

  def teardown
    Tochtli::ControllerManager.stop
  end

  def test_start_single_controller
    Tochtli::ControllerManager.start(FirstController, connection: @connection, logger: @logger)
    assert FirstController.started?
    refute SecondController.started?
    refute ThirdController.started?
  end

  def test_start_selected_controllers
    Tochtli::ControllerManager.start(FirstController, ThirdController, connection: @connection, logger: @logger)
    assert FirstController.started?
    refute SecondController.started?
    assert ThirdController.started?
  end

  def test_start_all_controllers
    Tochtli::ControllerManager.start(:all, connection: @connection, logger: @logger)
    assert FirstController.started?
    assert SecondController.started?
    assert ThirdController.started?
  end

  def test_restart_only_active_controllers
    Tochtli::ControllerManager.start(FirstController, SecondController, connection: @connection, logger: @logger)
    Tochtli::ControllerManager.restart(connection: @connection, logger: @logger)
    assert FirstController.started?
    assert SecondController.started?
    refute ThirdController.started?
  end

  def test_state_monitor
    Tochtli::ControllerManager.start(FirstController, connection: @connection, logger: @logger)
  end

	def test_multiple_queues
		Tochtli::ControllerManager.setup(connection: @connection, logger: @logger)
		Tochtli::ControllerManager.start(FirstController, queue_name: 'first_queue')
		Tochtli::ControllerManager.start(FirstController, queue_name: 'second_queue')

		assert_equal ["first_queue", "second_queue"], FirstController.dispatcher.queues.map(&:name).sort
	end

	def test_restart_multiple_queues
		Tochtli::ControllerManager.setup(connection: @connection, logger: @logger)
		Tochtli::ControllerManager.start(FirstController, queue_name: 'first_queue')
		Tochtli::ControllerManager.start(FirstController, queue_name: 'second_queue')
		Tochtli::ControllerManager.restart

		assert_equal ["first_queue", "second_queue"], FirstController.dispatcher.queues.map(&:name).sort
	end
end

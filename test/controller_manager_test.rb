require_relative 'test_helper'

Thread.abort_on_exception = true

class ControllerManagerTest < ServiceBase::Test::TestCase
	class FirstController < ServiceBase::BaseController
	end

	class SecondController < ServiceBase::BaseController
	end

	class ThirdController < ServiceBase::BaseController
	end

	setup do
		@logger = Logger.new(STDERR)
		@logger.level = Logger::WARN
	end

	teardown do
		ServiceBase::ControllerManager.stop
	end

	test 'start single controller' do
		ServiceBase::ControllerManager.start(FirstController, connection: @connection, logger: @logger)
		assert FirstController.started?
		refute SecondController.started?
		refute ThirdController.started?
	end

	test 'start selected controllers' do
		ServiceBase::ControllerManager.start(FirstController, ThirdController, connection: @connection, logger: @logger)
		assert FirstController.started?
		refute SecondController.started?
		assert ThirdController.started?
	end

	test 'start all controllers' do
		ServiceBase::ControllerManager.start(:all, connection: @connection, logger: @logger)
		assert FirstController.started?
		assert SecondController.started?
		assert ThirdController.started?
	end

	test 'restart only active controllers' do
		ServiceBase::ControllerManager.start(FirstController, SecondController, connection: @connection, logger: @logger)
		ServiceBase::ControllerManager.restart(connection: @connection, logger: @logger)
		assert FirstController.started?
		assert SecondController.started?
		refute ThirdController.started?
	end

	test 'state monitor' do
		ServiceBase::ControllerManager.start(FirstController, connection: @connection, logger: @logger)

	end
end

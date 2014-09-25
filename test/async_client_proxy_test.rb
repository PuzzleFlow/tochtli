require_relative 'test_helper'
require 'benchmark'

Thread.abort_on_exception = true

class AsyncClientProxyTest < ActionController::TestCase
	class Client
		def service_friendly_name
			"Test Service"
		end

		def sleepy_command(param, handler, options={})
			Thread.new do
				sleep 0.5
				handler.call 'OK'
			end
		end

		def buggy_command(param, handler, options={})
			handler.on_error 'StandardError', "Bug!"
		end
	end

	class AsyncClientProxy < ServiceBase::ClientProxy::Async
		delegate_command :sleepy_command, :buggy_command
	end

	class TestController < ActionController::Base
		rescue_from StandardError, with: :standard_error

		def sleepy
			client_proxy.sleepy_command(:param) do |response|
				render :text => response
			end
		end

		def buggy
			client_proxy.buggy_command(:param) do |response|
				render :text => 'Should not reach this place'
			end
		end

		protected

		def standard_error(exception)
			render :text => "Handled Error: #{exception.message}", :status => 501
		end

		def client_proxy
			unless @client_proxy
				@client = Client.new
				@client_proxy = AsyncClientProxy.new(@client, self)
			end
			@client_proxy
		end
	end

	tests TestController

	setup do
		Rails.application.routes.draw do
			match '/sleepy' => 'async_client_proxy_test/test#sleepy'
			match '/buggy' => 'async_client_proxy_test/test#buggy'
		end

		@controller.env['async.callback'] = Proc.new do |response|
			@async_response = response
		end
	end

	teardown do
		Rails.application.reload_routes!
	end

	test 'async command' do
		EM.run do
			catch :async do
				post :sleepy
			end

			assert_equal "", @response.body
			assert_nil @async_response

			EventMachine.add_timer(0.6) { EM.stop }
		end

		assert_response :success, "OK"
		assert_equal "OK", @async_response[2].body
	end

	test 'buggy command' do
		EM.run do
			catch :async do
				post :buggy
			end
			EventMachine.next_tick { EM.stop }
		end

		assert_equal "Handled Error: StandardError from Test Service: Bug!", @async_response[2].body
	end
end
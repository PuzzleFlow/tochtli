require_relative 'test_helper'
require 'benchmark'

Thread.abort_on_exception = true

class BlockingClientProxyTest < ActionController::TestCase
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

	class ClientProxy < ServiceBase::ClientProxy::Blocking
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
				@client_proxy = ClientProxy.new(@client, self)
			end
			@client_proxy
		end
	end

	tests TestController

	setup do
		Rails.application.routes.draw do
			match '/sleepy' => 'blocking_client_proxy_test/test#sleepy'
			match '/buggy' => 'blocking_client_proxy_test/test#buggy'
		end
	end

	teardown do
		Rails.application.reload_routes!
	end

	test 'async command' do
		post :sleepy
		assert_response :success, 'OK'
	end

	test 'buggy command' do
		post :buggy
		assert_response :error, "Handled Error: StandardError from Test Service: Bug!"
	end
end
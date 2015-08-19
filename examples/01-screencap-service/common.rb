require 'bundler'
Bundler.require

Tochtli.logger = Logger.new('tochtli.log')

class CreateScreenMessage < Tochtli::Message
	route_to 'screener.create'

	attribute :url
	attribute :file
end

class CreateScreenReplyMessage < Tochtli::Message
	attribute :time, type: Float
end
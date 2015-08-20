require_relative 'common'

Tochtli.logger.progname = 'CLIENT'

class ScreenerClient < Tochtli::BaseClient
  def create_screen(url, file_name)
    handler = SyncMessageHandler.new
    message = CreateScreenMessage.new(url: url, file: file_name)
    rabbit_client.publish message, handler: handler
    handler.wait!(20)
    puts "Done in #{handler.reply.time} seconds"
  end
end

ScreenerClient.new.create_screen(ARGV[0], ARGV[1])
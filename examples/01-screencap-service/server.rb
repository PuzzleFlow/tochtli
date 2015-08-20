require_relative 'common'

Tochtli.logger.progname = 'SERVER'

class ScreenerController < Tochtli::BaseController
  bind 'screener.*'

  on CreateScreenMessage, :create

  def create
    start_time = Time.now
    f = Screencap::Fetcher.new(message.url)
    f.fetch output: File.join(__dir__, 'images', message.file)
    total_time = Time.now - start_time
    reply CreateScreenReplyMessage.new(time: total_time)
  end
end

Tochtli::ControllerManager.setup
Tochtli::ControllerManager.start

trap('SIGINT') { exit }
at_exit { Tochtli::ControllerManager.stop }

puts 'Press Ctrl-C to stop worker...'
sleep

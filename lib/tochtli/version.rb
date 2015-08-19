module Tochtli
  VERSION = File.readlines(File.expand_path('../../../VERSION', __FILE__))[0].chomp unless defined?(VERSION)
end

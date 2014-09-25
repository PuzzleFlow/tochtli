require 'rubygems'

engine_path = File.expand_path('../../../..', __FILE__)

ENV['BUNDLE_GEMFILE'] = File.expand_path('Gemfile', engine_path)
require 'bundler'
Bundler.setup

# Bundler setup fix
# Bundler adds "-Ipath" option which does not work when path contains space
# Fix the path by adding ""
if ENV['RUBYOPT'] =~ /^(.*)-I(.+) -rbundler\/setup(.*)$/
	ENV['RUBYOPT'] = %Q(#{$1}"-I#{$2}" -rbundler/setup#{$3})
end

$:.unshift File.expand_path('lib', engine_path)
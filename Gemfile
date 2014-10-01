if RUBY_PLATFORM =~ /mswin/
	source 'https://gems.puzzleflow.com'
else
	source 'https://rubygems.org'
end

gem 'pg-binaries', require: 'pg_binaries'  if RUBY_PLATFORM =~ /mswin/

gemspec

rails_ver = ENV['RAILS_VER'] || '3.2.15' # Setup rails version for tests
gem 'rails', rails_ver
gem 'tzinfo-data' if RUBY_PLATFORM =~ /mswin|mingw/ && rails_ver >= '4.0' # require tzinfo-data only for Rails 4 on windows
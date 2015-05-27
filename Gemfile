unless RUBY_PLATFORM =~ /mswin/
	source 'https://rubygems.org'
end

source 'https://gems.puzzleflow.com' do
	gem 'hoe-puzzleflow'
	if RUBY_PLATFORM =~ /mswin/
		gem 'pg-binaries', require: 'pg_binaries'
		gem 'nokogiri'
	end
end

gemspec

rails_ver = ENV['RAILS_VER'] || '3.2.15' # Setup rails version for tests
gem 'rails', rails_ver
gem 'tzinfo-data' if RUBY_PLATFORM =~ /mswin|mingw/ && rails_ver >= '4.0' # require tzinfo-data only for Rails 4 on windows
gem 'minitest', rails_ver < '4.0' ? '~> 4.7.5' : '~> 5.4.2'
gem 'minitest-rails', rails_ver < '4.0' ? '~> 1.0.1' : '~> 2.1.1'
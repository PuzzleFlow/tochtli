if RUBY_PLATFORM =~ /mswin/
	source "https://support.puzzleflow.com/packages"
else
	source 'https://rubygems.org'
end

gem 'pg-binaries', require: 'pg_binaries'  if RUBY_PLATFORM =~ /mswin/
gem 'hoe', '~> 3.7.1'
gem 'hoe-git', '~> 1.6.0'
gem 'hoe-geminabox', '~> 0.3.0'
gem 'hoe-bundler', '~> 1.2.0'

# Declare your gem's dependencies in service_base.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# check the latest rails version, require tzinfo-data only for Rails 4
rails_spec = Gem::Specification.find_by_name('rails') rescue nil
gem 'tzinfo-data' if RUBY_PLATFORM =~ /mswin|mingw/ && rails_spec && rails_spec.version.to_s >= '4.0'
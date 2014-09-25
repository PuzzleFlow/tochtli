if RUBY_PLATFORM =~ /mswin/
	source "https://support.puzzleflow.com/packages"
else
	source 'https://rubygems.org'
end

gem 'tzinfo-data' if RUBY_PLATFORM =~ /mswin|mingw/
gem 'pg-binaries', require: 'pg_binaries'  if RUBY_PLATFORM =~ /mswin/

# Declare your gem's dependencies in service_base.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

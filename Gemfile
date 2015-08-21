source 'https://rubygems.org'

gem 'bunny', '~> 1.7.0'
gem 'uber', '>= 0.0.14'
gem 'virtus'
gem 'facets', require: false
gem 'hooks'

group :development do
  gem 'dalli', '~> 2.6.4'
  gem 'jeweler', '~> 2.0.1'

  gem 'mini_cache'
  gem 'yard', '~> 0.8'

  if ENV['RAILS_VER']
    gem 'sqlite3'
    rails_ver = ENV['RAILS_VER'] # Setup rails version for tests
    gem 'rails', rails_ver
    if rails_ver.to_i < 4
      gem 'test-unit', '>= 3.0.9'
    end
    gem 'tzinfo-data' if RUBY_PLATFORM =~ /mswin|mingw/ && rails_ver >= '4.0' # require tzinfo-data only for Rails 4 on windows
    gem 'minitest', rails_ver < '4.0' ? '~> 4.7.5' : '~> 5.4.2'
    gem 'minitest-rails', rails_ver < '4.0' ? '~> 1.0.1' : '~> 2.1.1'
  else
    #gem 'rails', '>= 3.2.15'
    gem 'minitest', '>= 4.7.5'
    gem 'minitest-reporters', '>= 0.5.0'
  end
end

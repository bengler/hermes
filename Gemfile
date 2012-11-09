source :rubygems

gem 'rake'
gem 'sinatra', '~> 1.3.2'
gem 'rack', '~> 1.4'
gem 'rack-contrib', '~> 1.1.0'
gem "activesupport", '~> 3.2.8'
gem 'pg', '~> 0.13.2'
gem 'yajl-ruby', '~> 1.1.0', :require => "yajl"
gem 'pebblebed', '~> 0.0.9'
gem 'petroglyph', '~> 0.0.2'
gem 'nokogiri', '~> 1.5.2'
gem 'excon', '~> 0.12.0'
gem 'httpclient'
gem 'airbrake', '~> 3.1.4', :require => false
gem 'pebbles-uid'
gem 'servolux'

group :test, :development do
  gem 'bengler_test_helper', :git => "git@github.com:bengler/bengler_test_helper.git"
end

group :test do
  gem 'rspec', '~> 2.8'
  gem 'rack-test'
  gem 'simplecov', :require => false
  gem 'webmock'
  gem 'rack-test'
end

group :development do
  gem 'thin'
end

group :production do
  gem 'unicorn'
end

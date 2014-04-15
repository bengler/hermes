source "https://rubygems.org"

gem 'rake'
gem 'sinatra', '~> 1.3.2'
gem 'rack', '~> 1.4'
gem 'rack-contrib', '~> 1.1.0'
gem "activesupport", '~> 3.2.8'
gem 'yajl-ruby', '~> 1.1.0', :require => "yajl"
gem 'pebblebed', '~> 0.0.9'
gem 'pebbles-cors', git: 'https://github.com/bengler/pebbles-cors.git'
gem 'nokogiri', '~> 1.5.2'
gem 'excon', '~> 0.12.0'
gem 'httpclient'
gem 'pebbles-uid'

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
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn'
end

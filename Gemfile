source "https://rubygems.org"

gem 'rake'
gem 'sinatra', '~> 1.3.2'
gem 'rack', '~> 1.4'
gem 'rack-contrib', '~> 1.1.0'
gem "activesupport", '~> 4.2.0'
gem 'yajl-ruby', '~> 1.1.0', :require => "yajl"
gem 'pebblebed', '~> 0.3.1'
gem 'pebbles-cors', git: 'https://github.com/bengler/pebbles-cors.git'
gem 'pebbles-river', '~> 0.2.1', git: 'https://github.com/bengler/pebbles-river.git'
gem 'nokogiri', '~> 1.5.2'
gem 'excon', '~> 0.12.0'
gem 'crack', '~> 0.3.2'
gem 'httpclient'
gem 'pebbles-uid'

group :test do
  gem 'rspec', '~> 2.99.0'
  gem 'rack-test'
  gem 'simplecov', :require => false
  gem 'webmock'
end

group :development do
  gem 'thin'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn'
end

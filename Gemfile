source 'https://rubygems.org'

gem 'rake', '~> 0.9.2.2'
gem 'sinatra', '~> 1.3.2'
gem 'rack', '~> 1.4'
gem 'rack-contrib', '~> 1.4.0'
gem "activesupport", '~> 4.2.0'
gem 'yajl-ruby', '~> 1.1.0', :require => 'yajl'
gem 'pebblebed', '~> 0.4.4'
gem 'pebbles-cors', git: 'https://github.com/bengler/pebbles-cors.git'
gem 'pebbles-river', '~> 0.2.1'
gem 'nokogiri', '~> 1.5.2'
gem 'excon', '~> 0.52.0'
gem 'crack', '~> 0.3.2'
gem 'httpclient', '~> 2.5.0'
gem 'pebbles-uid', '~> 0.0.9'
gem 'mail', '~> 2.6.3'

group :test do
  gem 'rspec', '~> 2.99.0'
  gem 'rack-test', '~> 0.6.2'
  gem 'simplecov', '~> 0.7.1', :require => false
  gem 'webmock', '~> 1.9.0'
end

group :development do
  gem 'thin', '~> 1.5.0'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn', '~> 4.8.3'
end

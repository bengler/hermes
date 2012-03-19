Bundler.require(:test)

require 'simplecov'
SimpleCov.add_filter 'spec'
SimpleCov.add_filter 'config'
SimpleCov.start

require File.expand_path('../../config/environment', __FILE__)

require 'rspec'
require 'rspec/autorun'
require 'rack/test'
require 'excon'
require 'webmock/rspec'
require 'webmock/http_lib_adapters/excon_adapter'
require 'pp'

RSpec.configure do |config|
  config.before(:all) do
    WebMock.reset!
  end
end

ENV['RACK_ENV'] ||= 'test'
Bundler.require(:test)

# Simplecov must be loaded before everything else
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
require 'stringio'
require 'pp'
require 'pebblebed/rspec_helper'


set :environment, :test

Pebblebed.config do
  host 'example.org'
end

LOGGER.level = Logger::FATAL

Dir.glob(File.expand_path('../helpers/*.rb', __FILE__)).each do |f|
  require f
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include StubbingHelper
  config.include RackHelper
  config.include Pebblebed::RSpecHelper

  config.before :each do
    WebMock.reset!
    stub_checkpoint_success!
  end
end

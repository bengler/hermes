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

set :environment, :test

LOGGER.level = Logger::FATAL

Dir.glob(File.expand_path('../helpers/*.rb', __FILE__)).each do |f|
  require f
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include StubbingHelper

  config.before :each do
    Hermes::Configuration.instance.load!(File.expand_path('..', __FILE__))
  end

  config.before :each do
    WebMock.reset!

    # FIXME: Good God, Lemon! (Move into specs!)
    stub_checkpoint_success!
    stub_mobiletech_success!
    stub_grove_update!
    stub_grove_post!
    stub_grove_get_post!
    stub_grove_update_success!
    stub_custom_callback_success!
    stub_grove_get_post_success!
    stub_grove_get_post_failure!
  end
end
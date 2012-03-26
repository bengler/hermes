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

RSpec.configure do |config|
  config.before :each do
    WebMock.reset!
  end
  config.around :each do |block|
    abort_class = Class.new(Exception) {}
    begin
      ActiveRecord::Base.transaction do
        block.call
        raise abort_class
      end
    rescue abort_class
    end
  end
end

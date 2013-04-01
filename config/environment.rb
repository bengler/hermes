require File.expand_path('config/site.rb') if File.exists?('config/site.rb')

require "bundler"
Bundler.require

require 'rack/contrib'
require 'yajl/json_gem'
require 'pebblebed/sinatra'
require 'timeout'
require 'excon'
require 'securerandom'
require 'singleton'
require 'active_support/all'

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

unless defined?(LOGGER)
  LOGGER = Logger.new($stderr)
  LOGGER.level = Logger::INFO
end

require File.expand_path('config/pebblebed.rb')

%w(
  lib/hermes/*.rb
  lib/hermes/providers/*.rb
  api/v1/*.rb
).each do |path|
  Dir.glob(File.expand_path("../../#{path}", __FILE__)).each do |f|
    require f
  end
end


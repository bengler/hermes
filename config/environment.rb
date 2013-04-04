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
require 'pathname'

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

unless defined?(LOGGER)
  LOGGER = Logger.new($stderr)
  LOGGER.level = Logger::INFO
end

Pebblebed.config do
  service :checkpoint, :version => 1
  service :grove, :version => 1
  host case ENV['RACK_ENV']
    when 'staging' then
      'pebbles.staging.o5.no'
    when 'production' then
      'pebbles.o5.no'
    else
      'hermes.dev'
  end
end

%w(
  lib/hermes/*.rb
  lib/hermes/providers/*.rb
  api/v1.rb
  api/v1/**/*.rb
).each do |path|
  Dir.glob(File.expand_path("../../#{path}", __FILE__)).each do |f|
    require f
  end
end


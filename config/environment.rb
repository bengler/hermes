require File.expand_path('config/site.rb') if File.exists?('config/site.rb')

require "bundler"
Bundler.require

require 'rack/contrib'
require 'yajl/json_gem'
require 'pebblebed/sinatra'
require 'sinatra/petroglyph'
require 'timeout'
require 'excon'
require 'securerandom'
require 'singleton'

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

unless defined?(LOGGER)
  LOGGER = Logger.new($stderr)
  LOGGER.level = Logger::INFO
end

%w(
  lib/hermes
  api/v1
).each do |path|
  Dir.glob(File.expand_path("../../#{path}/**/*.rb", __FILE__)).each do |f|
    require f
  end
end

ActiveRecord::Base.logger ||= LOGGER
ActiveRecord::Base.establish_connection(
  YAML::load(File.open("config/database.yml"))[environment])
Hermes::Configuration.instance.load!

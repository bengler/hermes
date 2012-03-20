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

%w(
  lib/hermes
  api/v1
).each do |path|
  Dir.glob(File.expand_path("../../#{path}/**/*.rb", __FILE__)).each do |f|
    require f
  end
end

Pebblebed.config do
  service :hermes
end

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

ActiveRecord::Base.logger = O5::LOG if defined?(O5::LOG)
ActiveRecord::Base.logger ||= Logger.new($stdout) if environment != 'test'
ActiveRecord::Base.logger ||= Logger.new('/dev/null')

Hupper.on_initialize do
  Hermes::Configuration.instance.load!
  ActiveRecord::Base.establish_connection(
    YAML::load(File.open("config/database.yml"))[environment])
end

Hupper.on_release do
  ActiveRecord::Base.connection.disconnect!
end

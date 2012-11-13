require File.expand_path('../config/environment', __FILE__)

set :environment, ENV['RACK_ENV'].to_sym

Hermes::Configuration.instance.load!

map '/api/hermes/v1/' do
  run Hermes::V1::MessagesController
end

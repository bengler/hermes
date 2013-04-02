require File.expand_path('../config/environment', __FILE__)

set :environment, ENV['RACK_ENV'].to_sym

Hermes::Configuration.instance.load!

map '/api/hermes/v1/' do
  use Rack::PostBodyContentTypeParser
  use Rack::MethodOverride
  use Pebbles::Cors
  run Hermes::V1
end

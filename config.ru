require File.expand_path('../config/environment', __FILE__)

ENV['RACK_ENV'] ||= 'development'
set :environment, ENV['RACK_ENV'].to_sym

use Rack::CommonLogger

map '/ping' do
  run Proc.new {|env| [200, {'Content-Type' => 'text/plain'}, ['hermes']]}
end

map '/api/hermes/ping' do
  run Proc.new {|env| [200, {'Content-Type' => 'text/plain'}, ['hermes']]}
end

map '/api/hermes/v1' do
  run Hermes::V1::MessagesController
end

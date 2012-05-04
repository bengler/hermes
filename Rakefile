require File.expand_path('../config/environment', __FILE__)

require 'sinatra/activerecord/rake'
if %w(test development).include?(ENV['RACK_ENV'])
  require 'bengler_test_helper/tasks'
end

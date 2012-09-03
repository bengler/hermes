require File.expand_path('../config/environment', __FILE__)

require 'sinatra/activerecord/rake'
if %w(test development).include?(ENV['RACK_ENV'])
  require 'bengler_test_helper/tasks'
  desc "bootstrap db user, recreate, run migrations"
  task :bootstrap do
    name = "hermes"
    `createuser -sdR #{name}`
    `createdb -O #{name} #{name}_development`
    Rake::Task['db:migrate'].invoke
    Rake::Task['db:test:prepare'].invoke
  end
end

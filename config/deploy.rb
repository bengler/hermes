set :application, 'hermes'
set :repository, 'git@github.com:bengler/hermes'
set :stages, ['production']
set :runner, 'hermes'
set :unicorn_config, '/srv/hermes/shared/config/unicorn.rb'
set :unicorn_pid, '/srv/hermes/shared/pids/unicorn.pid'

# Must be loaded after setting options
require 'capistrano/bengler'

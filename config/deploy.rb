set :application, 'hermes'
set :repository, 'git@github.com:bengler/hermes'
set :stages, ['production']
set :runner, 'hermes'
set :unicorn_config, '/srv/hermes/shared/config/unicorn.rb'
set :unicorn_pid, '/srv/hermes/shared/pids/unicorn.pid'

after :prepare, :config
task :config do
  run "sudo -u #{runner} ln -sfT #{shared_path}/config/realms #{current_path}/config/realms"
end

# Must be loaded after setting options
require 'capistrano/bengler'

set :application, 'hermes'
set :repository, 'git@github.com:bengler/hermes'

after :prepare, :config
task :config do
  run "sudo -u #{runner} ln -sfT #{shared_path}/config/realms #{current_path}/config/realms"
end

# Must be loaded after setting options
require 'capistrano/bengler'

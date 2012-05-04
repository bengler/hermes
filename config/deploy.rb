set :application, 'hermes'
set :repository, 'git@github.com:bengler/hermes'
set :stages, ['production', 'staging']
set :runner, 'hermes'

# Must be loaded after setting options
require 'capistrano/bengler'

set :rack_env, 'staging'

role :app, 'vitamin.park.origo.no'
role :web, 'vitamin.park.origo.no'
role :db, 'vitamin.park.origo.no', :primary => true

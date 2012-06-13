set :rack_env, 'staging'

role :app, 'brimnes.park.origo.no', 'hemnes.park.origo.no', 'riktig.park.origo.no', 'stabil.park.origo.no'
role :web, 'riktig.park.origo.no', 'stabil.park.origo.no'
role :db, 'brimnes.park.origo.no', :primary => true
role :db, 'hemnes.park.origo.no'

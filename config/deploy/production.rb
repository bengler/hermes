set :rack_env, 'production'

role :app, 'jara.park.origo.no', 'kivik.park.origo.no', 'lack.park.origo.no', 'marginal.park.origo.no', 'nominell.park.origo.no'
role :web, 'lack.park.origo.no', 'marginal.park.origo.no', 'nominell.park.origo.no'
role :db, 'lack.park.origo.no', :primary => true
role :db, 'marginal.park.origo.no', 'nominell.park.origo.no'

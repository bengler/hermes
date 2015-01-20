module Hermes

  class WrongRealmError < SecurityError; end

  class PebblesProxy

    @connectors = {}


    def self.connector_for(realm, checkpoint_identity, host)
      unless realm.name == checkpoint_identity.realm
        raise WrongRealmError.new("Realm mismatch #{realm.name} vs #{checkpoint_identity.realm}")
      end
      connector(realm.session_key, host)
    end


    def self.connector(session_key, host)
      key = "#{host}.#{session_key}"
      @connectors[key] ||= Pebblebed::Connector.new(session_key, host: host)
    end

  end

end

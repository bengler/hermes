# encoding: utf-8

module Hermes
  class V1 < Sinatra::Base

    configure do |config|
      config.set :root, File.expand_path('..', __FILE__)
      config.set :logging, true
      config.set :show_exceptions, false
    end

    register Sinatra::Pebblebed

    error ::Hermes::ProviderNotFound, ::Hermes::RealmNotFound do |e|
      return halt 404, e.message
    end

    error ::Hermes::OptionMissingError do |e|
      return halt 400, e.message
    end

    before do
      @configuration = Configuration.instance
      cache_control :private, :no_cache, :no_store, :must_revalidate
      headers "Content-Type" => "application/json; charset=utf8"
    end

    private

      def realm_and_provider(realm_name, provider_kind)
        realm = @configuration.realm(realm_name)
        provider = realm.provider(provider_kind)
        return realm, provider
      end

      def pebblebed_connector(realm, checkpoint_identity)
        unless realm.name == checkpoint_identity.realm
          halt 500, "Wrong realm #{realm.name.inspect}, " \
            "expected #{checkpoint_identity.realm.inspect}"
        end
        Pebblebed::Connector.new(realm.session_key)
      end

      def logger
        LOGGER
      end

  end
end
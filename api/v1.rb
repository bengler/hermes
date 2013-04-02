# encoding: utf-8

module Hermes
  class V1 < Sinatra::Base

    configure do |config|
      config.set :root, File.expand_path('..', __FILE__)
      config.set :logging, true
      config.set :show_exceptions, false
    end

    register Sinatra::Pebblebed

    error ::Hermes::Configuration::ProviderNotFound do |e|
      return halt 404, e.message
    end

    error ::Hermes::Configuration::SessionNotFound do |e|
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

    helpers do

      def pebblebed_connector(realm, checkpoint_identity)
        if realm == checkpoint_identity.realm
          Pebblebed::Connector.new(@configuration.session_for_realm(realm))
        else
          raise ArgumentError, "Wrong realm #{realm.inspect}"
        end
      end

      def logger
        LOGGER
      end

    end

  end
end

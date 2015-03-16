# encoding: utf-8

module Hermes
  class V1 < Sinatra::Base

    configure do |config|
      config.set :root, File.expand_path('..', __FILE__)
      config.set :logging, true
      config.set :show_exceptions, false
    end

    register Sinatra::Pebblebed

    error ::Timeout::Error do |e|
      logger.error "Timeout"
      failure!(status: 503, message: 'Timeout')
    end

    error ::Hermes::ProviderNotFound, ::Hermes::RealmNotFound do |e|
      logger.error e.message
      failure!(status: 404, message: e.message)
    end

    error ::Hermes::OptionMissingError, InvalidMessageError do |e|
      logger.error e.message
      failure!(status: 400, message: e.message)
    end

    error ::Hermes::RecipientRejectedError do |e|
      logger.error e.message
      failure! status: 400, message: e.message
    end

    not_found do
      failure!(status: 404, message: 'Not found')
    end

    before do
      LOGGER.info "Processing #{request.url}"
      LOGGER.info "Params: #{params.inspect}"
      cache_control :private, :no_cache, :no_store, :must_revalidate
    end

    helpers do
      def render_json(data)
        data = data.to_json if data.respond_to?(:to_json)
        headers "Content-Type" => "application/json; charset=utf-8"
        [200, data]
      end

      def success!(options)
        headers "Content-Type" => "text/plain; charset=utf-8"
        halt(options[:status] || 200, options[:message] || 'OK')
      end

      def failure!(options)
        headers "Content-Type" => "text/plain; charset=utf-8"
        halt(options[:status] || 500, options[:message] || 'Internal error')
      end
    end

    private

    def logger
      LOGGER
    end

  end
end

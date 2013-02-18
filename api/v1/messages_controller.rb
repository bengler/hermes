# encoding: utf-8

module Hermes
  module V1

    class MessagesController < Sinatra::Base

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

      error StandardError, Exception do |e|
        LOGGER.error e.message
        e.backtrace.each do |line|
          LOGGER.error line
        end
        if ENV['RACK_ENV'] == 'production'
          halt 500, "Internal error"
        else
          halt 500, e.message
        end
      end

      before do
        @configuration = Configuration.instance
        cache_control :private, :no_cache, :no_store, :must_revalidate
        headers "Content-Type" => "application/json; charset=utf8"
      end

      post '/:realm/test/:kind' do |realm, kind|
        provider = @configuration.provider_for_realm_and_kind(realm, kind.to_sym)
        if provider.test!
          halt 200, "Provider is fine"
        else
          halt 500, "Provider unavailable"
        end
      end

      get '/:realm/messages/:uid' do |realm, uid|
        message = nil
        begin
          message = Message.find(realm, uid)
        rescue Exception => e
          LOGGER.exception e if LOGGER.responds_to?(:exception)
          return halt 500, "Could not get message, inspect logs"
        end
        return halt 404, "No such message" unless message
        halt 200, message.to_json
      end

      # post email
      # params = {
      #   :recipient_number => params['recipient_number'],
      #   :sender_number => params['sender_number'],
      #   :recipient_email => params['recipient_email'],
      #   :sender_email => params['sender_email'],
      #   :subject => params['subject'],
      #   :text => params['text'],
      #   :html => params['html'],
      #   :callback_url => params['callback_url']
      # }
      post '/:realm/messages/:kind' do |realm, kind|
        require_god
        provider = @configuration.provider_for_realm_and_kind(realm, kind.to_sym)
        connector = pebblebed_connector(realm, current_identity)
        path = "#{realm}"
        path << ".#{params['path']}" if params['path']
        message = message_from_params(params.tap{|hs| hs.delete(:path)})
        begin
          if @configuration.actual_sending_allowed?(realm)
            external_id =  Message.external_id_prefix(provider) <<
                            provider.send_message!(
                              message.tap{|hs| hs.delete(:callback_url)}.
                                merge(:receipt_url => receipt_url(realm, kind.to_sym)))
          else
            external_id = Message.external_id_prefix(provider) << Time.now.to_i.to_s
            LOGGER.warn("Actual sending is not performed in #{ENV['RACK_ENV']} environment. " <<
              "Simulating external_id #{external_id} from provider")
          end
          post = connector.grove.post(
            "/posts/post.hermes_message:#{path}",
            {
              :post => {
                :document => message.merge(:kind => kind),
                :restricted => true,
                :tags => ["inprogress"],
                :external_id => external_id
              }
            }
          )
          LOGGER.warn("Sent #{kind}-message: #{post.to_hash.inspect}")
        rescue Pebblebed::HttpError => e
          return halt e.status, e.message
        end
        halt 200, post.to_json
      end

      post '/:realm/receipt/:kind' do |realm, kind|
        provider = @configuration.provider_for_realm_and_kind(realm, kind)
        raw = request.env['rack.input'].read if request.env['rack.input']
        raw ||= ''
        begin
          result = provider.parse_receipt(request.path_info, raw, params)
        rescue Exception => e
          logger.error("Ignoring exception during receipt parsing: #{e}")
        else
          if result[:id] and result[:status]
            message = Message.find_by_external_id(Message.external_id_prefix(provider) << result[:id], realm)
            if message
              message.add_tag!(result[:status])
            end
          end
        end
        ''
      end

      helpers do

        def message_from_params(params)
          hash = {
            :recipient_number => params['recipient_number'],
            :sender_number => params['sender_number'],
            :recipient_email => params['recipient_email'],
            :sender_email => params['sender_email'],
            :subject => params['subject'],
            :text => params['text'],
            :html => params['html'],
            :callback_url => params['callback_url']
          }
          if params['rate']
            hash.merge!(
              :rate => {
                :currency => (params['rate'])['currency'],
                :amount => (params['rate'])['amount']
              })
          end
          hash.select{|k,v| !v.blank?}
        end

        def pebblebed_connector(realm, checkpoint_identity)
          Pebblebed::Connector.new(@configuration.session_for_realm(realm)) if realm == checkpoint_identity.realm
        end

        def logger
          LOGGER
        end

        def receipt_url(realm, kind)
          # FIXME: Make configurable
          case ENV['RACK_ENV']
            when 'development'
              # Set up a tunnel on samla.park.origo.no port 10900 to receive receipts
              "http://origo.tunnel.o5.no/api/hermes/v1/#{realm}/receipt/#{kind}"
            when 'staging'
              "http://hermes.staging.o5.no/api/hermes/v1/#{realm}/receipt/#{kind}"
            else
              "http://hermes.o5.no/hermes/v1/#{realm}/receipt/#{kind}"
          end
        end
      end

    end

  end
end

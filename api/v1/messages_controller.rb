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

      get '/:realm/messages/:id' do |realm, id|
        require_god
        message = Message.where(:id => id)
        if message.any?
          if message.first.realm == realm
            return pg :message, :locals => {:message => message.first}
          end
        end
        halt 404, "No such message"
      end

      post '/:realm/messages/:kind' do |realm, kind|
        require_god
        provider = @configuration.provider_for_realm_and_kind(realm, kind.to_sym)
        connector = pebblebed_connector(realm, current_identity)
        attrs = JSON.parse(request.env['rack.input'].read)
        path = "#{realm}"
        path << ".#{attrs['path']}" if attrs['path']
        message = message_from_attrs(attrs.tap{|hs| hs.delete(:path)})
        post = connector.grove.post(
          "/posts/post.#{kind}_message:#{path}",
          {
            :post => {
              :document => message,
              :restricted => true,
              :tags => ["inprogress"],
              :external_id => Message.external_id_prefix(provider) <<
                provider.send_message!(
                  message.tap{|hs| hs.delete(:callback_url)}.
                    merge(:receipt_url => receipt_url(realm, kind.to_sym)))
            }
          }
        )
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

        def message_from_attrs(attrs)
          hash = {
            :recipient_number => attrs['recipient_number'],
            :sender_number => attrs['sender_number'],
            :recipient_email => attrs['recipient_email'],
            :sender_email => attrs['sender_email'],
            :subject => attrs['subject'],
            :text => attrs['text'],
            :html => attrs['html'],
            :callback_url => attrs['callback_url']
          }
          if attrs['rate']
            hash.merge!(
              :rate => {
                :currency => (attrs['rate'])['currency'],
                :amount => (attrs['rate'])['amount']
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
              "http://hermes.o5.no/api/hermes/v1/#{realm}/receipt/#{kind}"
            else
              "http://hermes.staging.o5.no/hermes/v1/#{realm}/receipt/#{kind}"
          end
        end
      end

    end

  end
end

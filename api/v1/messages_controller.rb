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
      end

      helpers do
        def logger
          LOGGER
        end

        def receipt_url(realm)
          # FIXME: Make configurable
          case ENV['RACK_ENV']
            when 'development'
              # Set up a tunnel on samla.park.origo.no port 10900 to receive receipts
              "http://origo.tunnel.o5.no/api/hermes/v1/#{realm}/receipt"
            when 'staging'
              "http://hermes.o5.no/api/hermes/v1/#{realm}/receipt"
            else
              "http://hermes.staging.o5.no/hermes/v1/#{realm}/receipt"
          end
        end
      end

      get '/:realm/stats/sms' do |realm|
        provider = @configuration.provider_for_realm_and_kind(realm, :sms)
        pg :statistics, :locals => {:statistics => Message.statistics(:realm => realm, :kind => 'sms')}
      end

      get '/:realm/stats/email' do |realm|
        provider = @configuration.provider_for_realm_and_kind(realm, :email)
        pg :statistics, :locals => {:statistics => Message.statistics(:realm => realm, :kind => 'email')}
      end

      post '/:realm/test/sms' do |realm|
        provider = @configuration.provider_for_realm_and_kind(realm, :sms)
        if provider.test!
          halt 200, "Provider is fine"
        else
          halt 500, "Provider unavailable"
        end
      end

      get '/:realm/messages/:id' do |realm, id|
        message = Message.where(:id => id)
        if message.any?
          if message.first.realm == realm
            return pg :message, :locals => {:message => message.first}
          end
        end
        halt 404, "No such message"
      end

      post '/:realm/messages/sms' do |realm|
        provider = @configuration.provider_for_realm_and_kind(realm, :sms)
        attrs = JSON.parse(request.env['rack.input'].read)
        id = provider.send_message!(
          :recipient_number => attrs['recipient_number'],
          :sender_number => attrs['sender_number'],
          :rate => {
            :currency => (attrs['rate'] || {})['currency'],
            :amount => (attrs['rate'] || {})['amount']
          },
          :body => attrs['body'],
          :receipt_url => receipt_url(realm),
          :bill => attrs['bill'])

        message = Message.create!(
          :vendor_id => id,
          :realm => realm,
          :status => 'in_progress',
          :kind => 'sms',
          :recipient => attrs['recipient_number'],
          :callback_url => attrs['callback_url'],
          :bill => attrs['bill'])

        response.status = 202
        response.headers['Location'] = url("#{realm}/messages/sms/#{message.id}")
        response.headers['Content-Type'] = 'text/plain'
        message.id.to_s
      end

      post '/:realm/messages/email' do |realm|
        provider = @configuration.provider_for_realm_and_kind(realm, :email)
        attrs = JSON.parse(request.env['rack.input'].read)
        id = provider.send_message!(
          :recipient_email => attrs['recipient_email'],
          :sender_email => attrs['sender_email'],
          :text => attrs['text'],
          :html => attrs['html'],
          :receipt_url => receipt_url(realm))
        message = Message.create!(
          :vendor_id => id,
          :realm => realm,
          :status => 'in_progress',
          :kind => 'sms',
          :recipient => attrs['recipient_email'],
          :callback_url => attrs['callback_url'])
        response.status = 202
        response.headers['Location'] = url("#{realm}/messages/email/#{message.id}")
        response.headers['Content-Type'] = 'text/plain'
        message.id.to_s
      end

      post '/:realm/receipt' do |realm|
        provider = @configuration.provider_for_realm_and_kind(realm, :sms)
        raw = request.env['rack.input'].read if request.env['rack.input']
        raw ||= ''
        begin
          result = provider.parse_receipt(request.path_info, raw)
        rescue Exception => e
          logger.error("Ignoring exception during receipt parsing: #{e}")
        else
          if result[:id] and result[:status]
            message = Message.
              where(:realm => realm).
              where(:vendor_id => result[:id]).first
            if message
              message.status = result[:status]
              message.save!
            end
          end
        end
        ''
      end

    end

  end
end

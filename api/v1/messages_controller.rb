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

      error ::Hermes::Configuration::ProviderNotFound do
        404
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

        def receipt_url(profile)
          # FIXME: Use the right stuff
          if ENV['RACK_ENV'] == 'development'
            # Set up a tunnel on samla.park.origo.no port 10900 to receive receipts
            "http://origo.tunnel.o5.no/api/hermes/v1/#{profile}/receipt"
          else
            url("#{profile}/receipt")
          end
        end
      end

      get '/stats' do
        pg :statistics, :locals => {:statistics => Message.statistics}
      end

      get '/:profile/stats' do |profile|
        pg :statistics, :locals => {:statistics => Message.statistics(:profile => profile)}
      end

      post '/:profile/test' do |profile|
        provider = @configuration.provider_for_profile(profile)
        if provider.test!
          halt 200, "Provider is fine"
        else
          halt 500, "Provider unavailable"
        end
      end

      get '/:profile/messages/:id' do |profile, id|
        message = Message.where(:profile => profile).where(:id => id).first
        if message
          pg :message, :locals => {:message => message}
        else
          404
        end
      end

      post '/:profile/messages' do |profile|
        provider = @configuration.provider_for_profile(profile)

        attrs = JSON.parse(request.env['rack.input'].read)

        id = provider.send_short_message!(
          :recipient_number => attrs['recipient_number'],
          :sender_number => attrs['sender_number'],
          :rate => {
            :currency => (attrs['rate'] || {})['currency'],
            :amount => (attrs['rate'] || {})['amount']
          },
          :body => attrs['body'],
          :receipt_url => receipt_url(profile))

        message = Message.create!(
          :vendor_id => id,
          :profile => profile,
          :status => 'in_progress',
          :recipient_number => attrs['recipient_number'],
          :callback_url => attrs['callback_url'])

        response.status = 202
        response.headers['Location'] = url("#{profile}/#{message.id}")
        response.headers['Content-Type'] = 'text/plain'
        message.id.to_s
      end

      post '/:profile/receipt' do |profile|
        provider = @configuration.provider_for_profile(profile)
        raw = request.env['rack.input'].read if request.env['rack.input']
        raw ||= ''
        begin
          result = provider.parse_receipt(request.path_info, raw)
        rescue Exception => e
          logger.error("Ignoring exception during receipt parsing: #{e}")
        else
          if result[:id] and result[:status]
            message = Message.
              where(:profile => profile).
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

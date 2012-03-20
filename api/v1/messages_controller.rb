# encoding: utf-8

module Hermes
  module V1

    class MessagesController < Sinatra::Base

      configure do |config|
        config.set :root, File.expand_path('..', __FILE__)
        config.set :logging, true
        config.set :logger, ActiveRecord::Base.logger
        config.set :show_exceptions, false
      end

      configure :development do |config|
        config.set :show_exceptions, true
      end

      register Sinatra::Pebblebed

      before do
        @configuration = Configuration.instance
      end

      helpers do
        def receipt_url(realm)
          # FIXME: Use the right stuff
          if ENV['RACK_ENV'] == 'development'
            # Set up a tunnel on samla.park.origo.no port 10900 to receive receipts
            "http://origo.tunnel.o5.no/api/hermes/v1/#{realm}/receipt"
          else
            url("#{realm}/receipt")
          end
        end
      end

      get '/:realm/:id' do |realm, id|
        message = Message.where(:realm => realm).where(:id => id).first
        if message
          pg :message, :locals => {:message => message}
        else
          404
        end
      end

      post '/:realm' do |realm|
        provider = @configuration.provider_for_realm(realm)

        attrs = JSON.parse(request.env['rack.input'].read)

        id = provider.send_short_message!(
          :recipient_number => attrs['recipient_number'],
          :sender_number => attrs['sender_number'],
          :rate => {
            :currency => (attrs['rate'] || {})['currency'],
            :amount => (attrs['rate'] || {})['amount']
          },
          :body => attrs['body'],
          :receipt_url => receipt_url(realm))

        message = Message.create!(
          :vendor_id => id,
          :realm => realm,
          :status => 'in_progress',
          :recipient_number => attrs['recipient_number'],
          :callback_url => attrs['callback_url'])

        response.status = 202
        response.headers['Location'] = url("#{realm}/#{message.id}")
        response.headers['Content-Type'] = 'text/plain'
        message.id.to_s
      end

      post '/:realm/receipt' do |realm|
        provider = @configuration.provider_for_realm(realm)
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

      error Configuration::ProviderNotFound do
        404
      end

    end

  end
end

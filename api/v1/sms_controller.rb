module Hermes
  module V1
    class MessagesController < Sinatra::Base

      post '/:realm/messages/sms' do |realm|
        require_god
        provider = @configuration.provider_for_realm_and_kind(realm, :sms)
        connector = pebblebed_connector(realm, current_identity)
        message = sms_message_from_attrs(JSON.parse(request.env['rack.input'].read))
        post = connector.grove.post(
          "/posts/post.sms:#{realm}",
          {
            :post => {
              :document => message,
              :tags => ["in_progress"],
              :external_id => Message.external_id_prefix(provider) <<
                provider.send_message!(
                  message.tap{|hs| hs.delete(:callback_url)}.
                    merge(:receipt_url => receipt_url(realm, :sms)))
            }
          }
        )
        halt 200, post.to_json
      end
      helpers do
        def sms_message_from_attrs(attrs)
          {
            :recipient_number => attrs['recipient_number'],
            :sender_number => attrs['sender_number'],
            :rate => {
              :currency => (attrs['rate'] || {})['currency'],
              :amount => (attrs['rate'] || {})['amount']
            },
            :body => attrs['body'],
            :callback_url => attrs['callback_url']
          }
        end
      end
    end
  end
end

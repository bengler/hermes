module Hermes
  module V1
    class MessagesController < Sinatra::Base


      post '/:realm/messages/email' do |realm|
        require_god
        provider = @configuration.provider_for_realm_and_kind(realm, :email)
        connector = pebblebed_connector(realm, current_identity)
        attrs = JSON.parse(request.env['rack.input'].read)
        path = "#{realm}"
        path << ".#{attrs['path']}" if attrs['path']
        message = email_message_from_attrs(attrs.tap{|hs| hs.delete(:path)})
        post = connector.grove.post(
          "/posts/post.email:#{path}",
          {
            :post => {
              :document => message,
              :restricted => true,
              :tags => ["inprogress"],
              :external_id => Message.external_id_prefix(provider) <<
                provider.send_message!(
                  message.tap{|hs| hs.delete(:callback_url)}.
                    merge(:receipt_url => receipt_url(realm, :email)))
            }
          }
        )
        halt 200, post.to_json
      end
      helpers do
        def email_message_from_attrs(attrs)
          {
            :recipient_email => attrs['recipient_email'],
            :sender_email => attrs['sender_email'],
            :subject => attrs['subject'],
            :text => attrs['text'],
            :html => attrs['html'],
            :callback_url => attrs['callback_url']
          }
        end
      end

    end
  end
end

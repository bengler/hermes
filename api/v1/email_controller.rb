module Hermes
  module V1
    class MessagesController < Sinatra::Base

      # @apidoc
      # Send an email
      #
      # @category Hermes/Email
      # @path /api/hermes/v1/:realm/email
      # @http POST
      # @example /api/hermes/v1/dna/email
      # @required [String] realm the configured realm to send with
      # @required [String] recipient_email the email address to send to
      # @optional [String] subject the message subject
      # @optional [String] text the message plain text
      # @optional [String] html the message HTML
      # @optional [String] sender_emaio the email address the email is sent from
      # @optional [String] callback_url the url that should be called when a new status for the message is set
      # @returns [JSON]
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

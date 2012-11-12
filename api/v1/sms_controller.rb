module Hermes
  module V1
    class MessagesController < Sinatra::Base

      # @apidoc
      # Send a SMS.
      #
      # @note Requires a god session.
      # @category Hermes/SMS
      # @path /api/hermes/v1/:realm/sms
      # @http POST
      # @example /api/hermes/v1/dna/sms
      # @required [String] realm the configured realm to send with
      # @required [String] recipient_number the mobile number to send to
      # @required [String] body the message text
      # @optional [String] sender_number the mobile number or sender label (string) that the message is sent form
      # @optional [String] callback_url the url that should be called when a new status for the message is set
      # @optional [Hash] rate a hash with {"currency": "NOK", "amount": "1"}
      # @returns [JSON]
      post '/:realm/messages/sms' do |realm|
        require_god
        provider = @configuration.provider_for_realm_and_kind(realm, :sms)
        connector = pebblebed_connector(realm, current_identity)
        attrs = JSON.parse(request.env['rack.input'].read)
        path = "#{realm}"
        path << ".#{attrs['path']}" if attrs['path']
        message = sms_message_from_attrs(attrs.tap{|hs| hs.delete(:path)})
        post = connector.grove.post(
          "/posts/post.sms:#{path}",
          {
            :post => {
              :document => message,
              :restricted => true,
              :tags => ["inprogress"],
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

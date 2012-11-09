module Hermes
  module V1
    class MessagesController < Sinatra::Base

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

    end
  end
end

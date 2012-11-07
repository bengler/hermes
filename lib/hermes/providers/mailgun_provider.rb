require "httpclient"

module Hermes
  module Providers

    class MailGunProvider

      attr_reader :api_key
      attr_reader :mailgun_domain

      class MailGunError < Exception; end
      class ConfigurationError < MailGunError; end
      class APIFailureError < MailGunError; end
      class InvalidResponseError < MailGunError; end
      class InvalidReceiptError < MailGunError; end

      def initialize(options = {})
        options.assert_valid_keys(:api_key, :mailgun_domain)
        @api_key = options[:api_key]
        raise ConfigurationError, "Api key must be specified" unless @api_key
        @mailgun_domain = options[:mailgun_domain]
        @default_sender_email = "No-reply <no-reply@#{@mailgun_domain}>"
        raise ConfigurationError, "Domain must be specified" unless @mailgun_domain
      end

      def send_message!(options)
        options.assert_valid_keys(:receipt_url, :sender_email, :recipient_email, :subject, :text, :html, :timeout)
        raise Hermes::OptionMissingError.new("recipient_email is missing") unless options[:recipient_email]
        raise Hermes::OptionMissingError.new("text is missing") unless options[:text]
        Timeout.timeout(options[:timeout] || 30) do
          url = "https://api.mailgun.net/v2/#{@mailgun_domain}/messages"
          client =  HTTPClient.new()
          client.set_auth(nil, "api", @api_key)
          response = client.post(
            url,
            post_data(
              options[:recipient_email],
              options[:sender_email] || @default_sender_email,
              options[:subject],
              options[:text],
              options[:html]
            )
          )
          raise APIFailureError.new(response.body) if [401, 402, 404].include?(response.status)
          if response.status == 200
            data = JSON.parse(response.body)
            return data["id"]
          else
            raise InvalidResponseError.new(response.inspect)
          end
        end
      end

      # Test whether provider is functional. Returns true or false.
      def test!
        begin
          send_message!(:recipient_email => '_', :subject => 'meh')
        rescue Excon::Errors::Error
          false
        rescue MessageRejectedError
          true
        else
          false  # Gateway is being weird, should never accept that message
        end
      end

      def parse_receipt(url, raw_data)
        parsed_data = JSON.parse(raw_data)
        id = parsed_data["id"]
        message = parsed_data["message"]
        result = {:id => id}
        result[:status] = :in_progress
        result[:vendor_message] = message
        result
      end

      private

        def post_data(recipient_email, sender_email, subject, text, html)
          {
            "to" => recipient_email,
            "from" => sender_email,
            "subject" => subject,
            "text" => text,
            "html" => html
          }
        end
    end

  end
end

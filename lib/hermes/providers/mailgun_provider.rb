require 'httpclient'
require 'rack/utils'

module Hermes
  module Providers

    class MailGunProvider

      attr_reader :api_key
      attr_reader :mailgun_domain

      class MailGunException < ProviderError; end

      class APIFailureError < MailGunException
        def initialize(message, status_code)
          super("#{message} (#{status_code})")
          @message, @status_code = message, status_code
        end
        attr_reader :message, :status_code
      end

      def initialize(options = {})
        options.assert_valid_keys(:api_key, :mailgun_domain)
        @api_key = options[:api_key]
        raise ConfigurationError, "Api key must be specified" unless @api_key
        @mailgun_domain = options[:mailgun_domain]
        @default_sender_email = "No-reply <no-reply@#{@mailgun_domain}>"
        raise ConfigurationError, "Domain must be specified" unless @mailgun_domain
      end

      def send_message!(options)
        options.assert_valid_keys(:receipt_url, :sender_email, :recipient_email, :subject, :text, :html)
        raise Hermes::OptionMissingError.new("recipient_email is missing") unless options[:recipient_email]
        raise Hermes::OptionMissingError.new("text is missing") unless options[:text]
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
        case response.status
          when 200
            begin
              return JSON.parse(response.body)['id']
            rescue
              raise InvalidResponseError, "Invalid JSON from server"
            end
          when 400
            begin
              json = JSON.parse(response.body)
            rescue
              raise InvalidResponseError, "Invalid JSON from server in HTTP 400 response"
            else
              if (message = json['message'])
                case message
                  when /\A'to' parameter is not a valid address/
                    raise RecipientRejectedError.new(options[:recipient_email], message)
                end
              end
              raise APIFailureError.new(message, response.status)
            end
          else
            begin
              message = JSON.parse(response.body)['message']
            rescue
              message = "HTTP error #{response.status}"
            end
            raise APIFailureError.new(message, response.status)
        end
      end

      # Test whether provider is functional. Returns true or false.
      def test!
        begin
          send_message!(:recipient_email => '_', :subject => 'meh')
        rescue Excon::Errors::Error
          false
        rescue MessageRejectedError, RecipientRejectedError
          true
        else
          false  # Gateway is being weird, should never accept that message
        end
      end

      def parse_receipt(url, raw_data, params=nil)
        id = params["Message-Id"]
        status = case params["event"]
          when "bounced"
            :failed
          when "delivered"
            :delivered
          when "dropped"
            :failed
          else
            :unknown
        end
        result = {:id => id}
        result[:status] = status
        result[:vendor_message] = params["error"]
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

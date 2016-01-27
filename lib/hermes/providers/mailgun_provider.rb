require 'httpclient'
require 'rack/utils'

module Hermes
  module Providers

    class MailGunProvider

      # How often a failed (ie., unregistered) domain will be retried. If a
      # domain is not known, the default domain will be used if configured.
      FAILED_DOMAIN_RECHECK_INTERVAL = 1.minute

      attr_reader :api_key
      attr_reader :mailgun_domain

      class MailGunException < ProviderError; end

      class DomainNotFoundError < MailGunException
        def initialize(domain)
          super("Domain #{domain} not found")
          @domain = domain
        end
        attr_reader :domain
      end

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
        if @mailgun_domain
          @default_sender_email = "No-reply <no-reply@#{@mailgun_domain}>"
        end
        @failed_domains = {}
      end

      def send_message!(options)
        options.assert_valid_keys(:receipt_url, :bcc_email, :sender_email, :recipient_email, :subject, :text, :html)
        raise Hermes::OptionMissingError.new("recipient_email is missing") unless options[:recipient_email]
        raise Hermes::OptionMissingError.new("text is missing") unless options[:text]

        sender_email = options[:sender_email] || @default_sender_email
        unless sender_email or @default_sender_email
          raise Hermes::OptionMissingError.new("sender_email required")
        end

        begin
          sender = Mail::Address.new(Mail::Encodings.address_encode(sender_email))
        rescue Mail::Field::ParseError => e
          raise RecipientRejectedError.new(sender_email, e.message)
        end
        unless sender.domain
          raise Hermes::OptionInvalidError, "Invalid sender: Domain missing"
        end

        # First, try the sender domain
        if should_send_with_domain?(sender.domain)
          begin
            return try_send_with_domain(options, sender.domain)
          rescue DomainNotFoundError => e
            raise unless @mailgun_domain
            logger.warn("Sending through #{e.domain} failed, falling back to default domain")
          end
        end

        # Fall back to mailgun domain
        try_send_with_domain(options, @mailgun_domain)
      end

      # Test whether provider is functional. Returns true or false.
      def test!
        begin
          send_message!(:recipient_email => '_', :subject => 'meh')
        rescue Excon::Errors::Error, Timeout::Error
          false
        rescue MessageRejectedError, RecipientRejectedError
          true
        else
          false  # Gateway is being weird, should never accept that message
        end
      end

      def parse_receipt(request)
        result = {:id => request.params["Message-Id"]}
        result[:status] = case request.params["event"]
          when "bounced"
            :failed
          when "delivered"
            :delivered
          when "dropped"
            :failed
          else
            :unknown
        end
        result[:vendor_message] = request.params["error"] || request.params["description"]
        result
      end

      private

        def try_send_with_domain(options, domain)
          client =  HTTPClient.new()
          client.set_auth(nil, "api", @api_key)

          payload = {
            "to" => options[:recipient_email],
            "from" => options[:sender_email],
            "subject" => options[:subject],
            "text" => options[:text],
            "html" => options[:html]
          }
          if (bcc = options[:bcc_email]) && bcc.present?
            payload['bcc'] = bcc
          end

          response = client.post(
            "https://api.mailgun.net/v2/#{domain}/messages", payload)

          body = get_json(response)

          if response.status == 200
            @failed_domains.delete(domain)
            return body['id']
          end

          if (message = body['message'])
            case message
              when /\A'to' parameter is not a valid address/
                raise RecipientRejectedError.new(options[:recipient_email], message)
              when /\ADomain not found:/
                @failed_domains[domain] = Time.now
                raise DomainNotFoundError.new(domain)
            end
          else
            message = "HTTP error #{response.status}"
          end
          raise APIFailureError.new(message, response.status)
        rescue HTTPClient::TimeoutError
          raise Timeout::Error, "Mailgun API timeout while sending"
        end

        def should_send_with_domain?(domain)
          if @mailgun_domain.blank?
            true
          elsif (timestamp = @failed_domains[domain])
            timestamp < Time.now - FAILED_DOMAIN_RECHECK_INTERVAL
          else
            true
          end
        end

        def get_json(response)
          type = [response.header["Content-Type"]].flatten.first
          if type and MIME::Types[type].first.try(:content_type) == 'application/json'
            return JSON.parse(response.body)
          else
            raise InvalidResponseError, "Expected JSON from server, got #{response.body.inspect}"
          end
        end

        def logger
          LOGGER
        end

    end

  end
end

require 'active_support/core_ext/hash/keys'

module Hermes
  module Providers

    class VianettProvider

      class VianettException < ProviderError; end

      # Base class for API errors.
      class APIError < VianettException
        def initialize(message, status_code, refno)
          super("#{message} (#{status_code})")
          @message, @status_code, @refno = message, status_code, refno
        end
        attr_reader :message, :status_code, :refno
      end

      # Thrown when the API fails with an unexpected error.
      class InternalError < APIError; end

      # Thrown when the API rejects a message, eg. due to invalid data.
      class MessageRejectedError < APIError; end

      attr_reader :user_name
      attr_reader :password
      attr_reader :default_sender

      def initialize(options = {})
        options.assert_valid_keys(
          :username, :password, :default_sender)

        @username = options[:username]
        raise ConfigurationError, "'username' must be specified" unless @username

        @password = options[:password]
        raise ConfigurationError, "'password' must be specified" unless @password

        if (default_sender = options[:default_sender]) && default_sender[:number]
          @default_sender = {
            :number => default_sender[:number],
            :type => default_sender[:type].try(:to_sym) || :msisdn
          }.freeze
        end

        @connection = Excon.new(BASE_URI)
      end

      def send_message!(options)
        options.assert_valid_keys(
          :receipt_url, :sender_number, :recipient_number, :text, :timeout)

        id = generate_id
        Timeout.timeout(options[:timeout] || 30) do
          params = build_params(id, options)
          logger.info "[Vianett] Posting outgoing: #{params.inspect}"
          check_response(
            @connection.post(
              path: OUTGOING_PATH,
              query: params))
        end
        id
      end

      # Test whether provider is functional. Returns true or false.
      def test!
        begin
          send_message!(recipient_number: '_', text: '')
        rescue Excon::Errors::Error
          false
        rescue MessageRejectedError
          true
        else
          false  # Gateway is being weird, should never accept that message
        end
      end

      def parse_receipt(url, raw_data, params = nil)
        result = {}
        case params[:requesttype]
          when 'notificationstatus'
            result[:vendor_status] = params[:Status].to_s.downcase
            result[:vendor_message] = params[:StatusDescription]
            case params[:vendor_status]
              when 'acceptd', 'bufferd'
                result[:status] = :sent
              when 'deliverd'
                result[:status] = :delivered
              else
                raise InvalidReceiptError
            end
          when 'mtstatus'
            result[:vendor_status] = params[:ErrorCode]
            result[:vendor_message] = params[:ErrorDescription]
            if params[:msgok] =~ /true/i
              result[:status] = :delivered
            else
              result[:status] = :failed
            end
          else
            raise InvalidReceiptError
        end
        result[:id] = params[:refno] if params[:refno]
        result
      end

      def ack_receipt(result, controller)
        id = result[:id]
        controller.halt 200,
          "<?xml version='1.0'?>" \
          "<ack refno='#{id}' errorcode='0'></ack>"
      end

      private

        BASE_URI = 'https://smsc.vianett.no/'.freeze
        OUTGOING_PATH = '/V3/CPA/MT/MT.ashx'.freeze

        def logger
          LOGGER
        end

        def check_response(response)
          unless response.body.present?
            raise InvalidResponseError, "Server returned empty body with status #{response.status}"
          end
          begin
            doc = Nokogiri::XML(response.body)
          rescue Nokogiri::XML::SyntaxError => e
            raise InvalidResponseError, "Invalid response from gateway: #{response.body.inspect}"
          else
            if (ack = doc.xpath('/ack').first)
              case ack['errorcode']
                when '200'
                  # This means success
                when '5000'
                  raise InternalError.new(
                    ack.content.present? ? ack.content : "Unknown error",
                    ack['errorcode'].to_i, ack['refno'].try(:to_i))
                else
                  raise MessageRejectedError.new(
                    ack.content.present? ? ack.content : "Unknown error",
                    ack['errorcode'].to_i, ack['refno'].try(:to_i))
              end
            else
              raise InvalidResponseError, "Server returned invalid body: #{response.body.inspect}"
            end
          end
        end

        def build_params(id, options)
          params = {
            msgid: id,
            username: @username,
            password: @password,
            Tel: number_to_msisdn(options[:recipient_number]),
            msg: options[:text].encode('utf-8')
          }

          if (sender = options[:sender_number]) && sender.present?
            params[:senderaddress] = sender
            params[:senderaddresstype] = sender =~ /\A\s*\+?[0-9\s]+\s*\z/ ? 1 : 5
          elsif (default_sender = @default_sender)
            case default_sender[:type]
              when :short_code
                params[:senderaddress] = default_sender[:number]
                params[:senderaddresstype] = 2
              when :alphanumeric
                params[:senderaddress] = default_sender[:number]
                params[:senderaddresstype] = 5
              when :msisdn
                params[:senderaddress] = default_sender[:number]
                params[:senderaddresstype] = 1
            end
          end

          params
        end

        def number_to_msisdn(number)
          if number =~ /^\+(.*)/
            $1
          else
            number
          end
        end

        def generate_id
          id = Time.now.strftime('%Y%m%d%H%M%S')
          id << SecureRandom.random_number(999).to_s
        end

    end

  end
end
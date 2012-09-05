module Hermes
  module Providers

    class MobiletechProvider

      class MobiletechError < Exception; end
      class ConfigurationError < Exception; end
      class InvalidResponseError < MobiletechError; end
      class InvalidReceiptError < MobiletechError; end
      class MessageRejectedError < MobiletechError; end
      class APIFailureError < MobiletechError; end
      class ReceiptProviderMismatchError < MobiletechError; end

      attr_reader :cpid
      attr_reader :default_prefix
      attr_reader :default_sender_country
      attr_reader :default_sender_number

      def initialize(options = {})
        options.assert_valid_keys(:cpid, :default_prefix, :default_sender_country, :secret,
          :default_sender_number)
        
        @cpid = options[:cpid].to_s if options[:cpid]
        raise ConfigurationError, "CPID must be specified" unless @cpid

        @secret = options[:secret]
        raise ConfigurationError, "Secret must be specified" unless @secret
        
        @default_prefix = options[:default_prefix] || DEFAULT_PREFIX
        @default_sender_country = options[:default_sender_country] || DEFAULT_SENDER_COUNTRY
        @default_sender_number = options[:default_sender_number]

        @connection = Excon.new(URL)
      end

      def send_short_message!(options)
        options.assert_valid_keys(
          :receipt_url, :rate, :recipient_number, :sender_number, :body, :timeout)
        tid = generate_tid
        Timeout.timeout(options[:timeout] || 30) do
          body = build_request(tid, options)
          LOGGER.info "Posting batch to Mobiletech: #{body}"
          response = @connection.post(
            :path => BATCH_SERVICE_PATH,
            :body => body,
            :headers => {'Content-Type' => 'application/xml'})
          case response.status
            when 200, 201
              parse_result(response.body)
            when 310
              raise APIFailureError, "Invalid transaction ID"
            when 312
              raise APIFailureError, "Invalid signature"
            when 500..599
              parse_error(response.body)
            else
              raise InvalidResponseError, "Server responded with status #{response.status}"
          end
        end
        tid
      end

      # Test whether provider is functional. Returns true or false.
      def test!
        begin
          send_short_message!(:recipient_number => '_', :body => '')
        rescue Excon::Errors::Error
          false
        rescue MessageRejectedError
          true
        else
          false  # Gateway is being weird, should never accept that message
        end
      end

      def parse_receipt(url, raw_data)
        document = Nokogiri::XML(raw_data, nil, nil, NOKOGIRI_PARSE_OPTIONS)
        cpid = document.xpath("/BatchReport/CpId").text
        if cpid != @cpid
          raise ReceiptProviderMismatchError, "Expected receipt for provider with CPID #{@cpid}, got for #{cpid.inspect}"
        end
        tid = document.xpath("/BatchReport/TransactionId").text
        if tid.empty?
          raise InvalidReceiptError, "Invalid receipt from Mobiletech missing transaction ID: #{raw_data}"
        end

        result = {:id => tid}
        if document.xpath("//BatchReport/Successful").text.to_i == 1
          result[:status] = :delivered
        elsif document.xpath("//BatchReport/Failed").text.to_i > 0
          result[:status] = :failed
          result[:vendor_status] = document.xpath("//MessageReport[1]/StatusCode").text
          result[:vendor_message] = document.xpath("//MessageReport[1]/StatusMessage").text
        elsif document.xpath("//BatchReport/Unknown").text.to_i > 0
          result[:status] = :unknown
        elsif document.xpath("//BatchReport/RequestedAmount").text.to_i > 0
          result[:status] = :in_progress
        else
          raise InvalidReceiptError, "Invalid receipt from Mobiletech missing fail/success data: #{raw_data}"
        end
        result
      rescue Nokogiri::XML::SyntaxError => e
        raise InvalidReceiptError, "Invalid receipt from Mobiletech: #{raw_data}"
      end
        
      private

        URL = 'http://msggw.dextella.net'.freeze

        BATCH_SERVICE_PATH = '/BatchService'.freeze

        FALSE_RESPONSE = 'false'.freeze

        DEFAULT_SENDER_COUNTRY = 'NO'.freeze
      
        DEFAULT_PREFIX = '47'

        NOKOGIRI_PARSE_OPTIONS =
          Nokogiri::XML::ParseOptions::NOBLANKS |
          Nokogiri::XML::ParseOptions::STRICT

        XMLNS = {
          "msg" => "http://mobiletech.com/dextella/msggw",
          "batch" => "http://batch.common.msggw.dextella.mobiletech.com",
          "soap" => "http://schemas.xmlsoap.org/soap/envelope/"
        }.freeze

        def number_to_msisdn(number)
          if number =~ /^\+(.*)/
            return $1
          else
            return "#{@default_prefix}#{number}"
          end
        end

        def generate_signature(parts)
          digest = Digest::SHA1.new
          digest.update(@cpid)
          parts.each do |part|
            digest.update(part) if part
          end
          digest.update(@secret)
          Base64.encode64(digest.digest).strip
        end

        def generate_tid
          # Mobiletech imposes a 36-character limit on transaction IDs
          id = Time.now.strftime('%Y%m%dT%H%M%S-')
          id << SecureRandom.random_number(2 ** 112).to_s(36)
        end

        def build_request(tid, options)
          Nokogiri::XML::Builder.new { |xml|
            xml.Envelope(
              "xmlns" => "http://schemas.xmlsoap.org/soap/envelope/",
              "xmlns:msg" => "http://mobiletech.com/dextella/msggw",
              "xmlns:bat" => "http://batch.common.msggw.dextella.mobiletech.com",
              "xmlns:mes" => "http://message.common.msggw.dextella.mobiletech.com") do
              xml.Header
              xml.Body do
                xml['msg'].batchSmsRequest do
                  xml['bat'].cpId do
                    xml.text @cpid
                  end
                  xml['bat'].defaultText do
                    xml.text options[:body]
                  end
                  xml['bat'].messages do
                    xml['mes'].SmsMessage do
                      xml['mes'].msisdn do
                        xml.text number_to_msisdn(options[:recipient_number])
                      end
                    end
                  end
                  sender_number = options[:sender_number]
                  sender_number ||= @default_sender_number
                  if sender_number
                    xml['bat'].prefShortNbrs do
                      xml['mes'].ShortNumber do
                        if @default_sender_country
                          xml['mes'].countryCode do
                            xml.text @default_sender_country
                          end
                        end
                        xml['mes'].shortNumber do
                          xml.text sender_number
                        end
                      end
                    end
                  end
                  xml['bat'].msgPrice do
                    rate = options[:rate] || {}
                    xml['mes'].currency do
                      xml.text((rate[:currency] || 'NOK').to_s)
                    end
                    xml['mes'].price do
                      xml.text((rate[:amount] || 0).to_s)
                    end
                  end
                  if options[:receipt_url]
                    xml['bat'].responseUrl do
                      xml.text options[:receipt_url]
                    end
                  end
                  xml['bat'].signature do
                    xml.text generate_signature([tid, options[:receipt_url]])
                  end
                  xml['bat'].transId do
                    xml.text tid
                  end      
                end
              end
            end
          }.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)
        end

        def parse_result(body)
          body = message_from_soap_envelope(body)

          document = Nokogiri::XML(body, nil, nil, NOKOGIRI_PARSE_OPTIONS)

          validity_response = document.xpath("//batch:validBatch", XMLNS).text
          if validity_response.empty?
            raise InvalidResponseError, "Invalid response from Mobiletech gateway: #{body}"
          end
          validity_response.strip!
          if validity_response == FALSE_RESPONSE
            error_messages = document.xpath("//batch:errorMessages/msg:string/text()", XMLNS).map { |message|
              message.to_s.strip
            }
            raise MessageRejectedError, "Message rejected by Mobiletech API: #{error_messages.join('; ')}"
          end
        rescue Nokogiri::XML::SyntaxError => e
          raise InvalidResponseError, "Invalid response from Mobiletech gateway: #{body}"
        end

        def parse_error(body)
          begin
            body = message_from_soap_envelope(body)
          rescue InvalidResponseError
            message = ''
          else            
            document = Nokogiri::XML(body, nil, nil, NOKOGIRI_PARSE_OPTIONS)
            message = document.xpath('//faultstring').text
          end
          if message.empty?
            raise APIFailureError, "Server responded with unknown error"
          else
            raise APIFailureError, "Server responded with error: #{message}"
          end
        end

        def message_from_soap_envelope(body)
          # FIXME: Mobiletech always returns a multipart MIME response
          #   with this SOAP envelope. We cheat and avoid parsing it correctly,
          #   but ideally we should use a MIME parser.
          if body =~ /(<soap:Envelope.*>.*<\/soap:Envelope>)/m
            $1
          else
            raise InvalidResponseError, "Invalid SOAP envelope from gateway: #{body}"
          end
        end

    end

  end
end
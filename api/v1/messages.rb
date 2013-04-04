# encoding: utf-8

module Hermes
  class V1 < Sinatra::Base

    # @apidoc
    # Get latest messages sent in a realm. Note: only works in non-production mode.
    # This is used for reading not actually sent messages in development/staging environment.
    #
    # @category Hermes/Public
    # @path /api/hermes/v1/:realm/messages/latest
    # @http GET
    # @example /api/hermes/v1/apdm/messages/latest
    # @required [String] realm The realm sending messages for.
    # @status 200 The twenty latest messages
    get '/:realm/messages/latest' do |realm|
      unless ENV['RACK_ENV'] == "production"
        messages = []
        begin
          messages = Message.find(realm, "post.hermes_message:*")
        rescue => e
          logger.exception e if logger.respond_to?(:exception)
          return halt 500, "Could not get messages, inspect logs"
        end
        halt 200, messages.to_json
      else
        halt 403, "Not allowed for production environment!"
      end
    end

    # @apidoc
    # Get a message from a UID to read status etc.
    #
    # @category Hermes/Public
    # @path /api/hermes/v1/:realm/messages/:uid
    # @http GET
    # @example /api/hermes/v1/apdm/messages/post.hermes_message:apdm.vanilla$616447
    # @required [String] realm The realm sending messages for.
    # @required [String] uid The message UID
    # @status 200 The message as stored in Grove with status of the message stored in the 'tags' field.
    get '/:realm/messages/:uid' do |realm, uid|
      require_god
      message = Message.get(realm, uid)
      return halt 404, "No such message" unless message
      halt 200, message.to_json
    end

    # @apidoc
    # Send a message of type :kind. Please note that options may vary depending on the type of message.
    # For a e-mail message, relevant options are: 'recipient_email', 'sender_email', subject', 'text' and 'html'
    # For a sms-message, relevant options are: 'sender_number', 'recipient_number', 'text'
    # All other options are common for all kind of messages.
    #
    # @category Hermes/Public
    # @path /api/hermes/v1/:realm/messages/:kind
    # @http POST
    # @example /api/hermes/v1/apdm/messages/email
    # @required [String] realm The realm sending messages for.
    # @required [String] kind Kind of message - 'sms' or 'email'.
    # @optional [String] recipient_number The number of the recipient if 'sms' message.
    # @optional [String] sender_number The number or shortname of the sender if 'sms' message.
    # @optional [String] sender_email The email address of the sender if 'email' message. Can be of format 'Some name <someone@somwhere.com>' or just 'someone@somwhere.com'.
    # @optional [String] recipient_email The email address of the recipient if 'email' message. Can be of format 'Some name <someone@somwhere.com>' or just 'someone@somwhere.com'.
    # @optional [String] subject The email subject if 'email' message.
    # @optional [String] text The message text for 'sms' message or 'email' plain text version.
    # @optional [String] html The html message text for 'email' message.
    # @optional [String] force A recipient mobile number or email address to send the message to, for testing purposes. Overrides what's given in the recipient parameters.
    # @optional [String] callback_url A URL which will be called when the message is delivered.
    # @status 200 The message as stored in Grove with status of the message stored in the 'tags' field.
    post '/:realm/messages/:kind' do |realm, kind|
      require_god

      @realm, @provider = realm_and_provider(realm, kind)

      message = {
        text: params[:text],
        callback_url: params[:callback_url]
      }
      case kind.to_sym
        when :sms
          message[:recipient_number] = params[:recipient_number]
          message[:sender_number] = params[:sender_number]
          if (rate = params[:rate]) and rate.is_a?(Hash)
            message[:rate] = {
              currency: rate[:currency],
              amount: rate[:amount]
            }
          end
        when :email
          message[:recipient_email] = params[:recipient_email]
          message[:sender_email] = params[:sender_email]
          message[:subject] = params[:subject]
          message[:html] = params[:html]
      end
      message.select! { |k, v| !v.blank? }

      raw_message = message.dup
      raw_message.delete(:callback_url)
      raw_message[:receipt_url] = @realm.receipt_url || legacy_receipt_url(@realm, kind.to_sym)

      if @realm.perform_sending? or params[:force]
        if params[:force]
          raw_message[:recipient_email] = params[:force] if kind == "email"
          raw_message[:recipient_number] = params[:force] if kind == "sms"
        end
        id = @provider.send_message!(raw_message)
        external_id = Message.build_external_id(@provider, id)
      else
        external_id = Message.build_external_id(@provider, Time.now.to_i.to_s)
        logger.warn("Actual sending is not performed in #{ENV['RACK_ENV']} environment. " \
          "Simulating external_id #{external_id} from provider")
      end

      begin
        post = pebblebed_connector(@realm, current_identity).grove.post(
          "/posts/post.hermes_message:" + [@realm.name, params[:path]].compact.join('.'),
          post: {
            document: message.merge(kind: kind),
            restricted: true,
            tags: ["inprogress"],
            external_id: external_id
          })
      rescue Pebblebed::HttpError => e
        # FIXME: This is way too generous
        return halt e.status, e.message
      else
        json_data = post.to_json
        logger.info("Sent message (#{kind} via #{@provider.class.name}): #{json_data}")
        halt 200, json_data
      end
    end

    private

      def legacy_receipt_url(realm, kind)
        # FIXME: Put in config
        case ENV['RACK_ENV']
          when 'development'
            # Set up a tunnel on samla.park.origo.no port 10900 to receive receipts
            "http://origo.tunnel.o5.no/api/hermes/v1/#{realm}/receipt/#{kind}"
          when 'staging'
            "http://hermes.staging.o5.no/api/hermes/v1/#{realm}/receipt/#{kind}"
          else
            "http://hermes.o5.no/hermes/v1/#{realm}/receipt/#{kind}"
        end
      end

  end
end

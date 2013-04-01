# encoding: utf-8

module Hermes
  module V1

    class MessagesController < Sinatra::Base

      configure do |config|
        config.set :root, File.expand_path('..', __FILE__)
        config.set :logging, true
        config.set :show_exceptions, false
      end

      register Sinatra::Pebblebed

      error ::Hermes::Configuration::ProviderNotFound do |e|
        return halt 404, e.message
      end

      error ::Hermes::Configuration::SessionNotFound do |e|
        return halt 404, e.message
      end

      error ::Hermes::OptionMissingError do |e|
        return halt 400, e.message
      end

      before do
        @configuration = Configuration.instance
        cache_control :private, :no_cache, :no_store, :must_revalidate
        headers "Content-Type" => "application/json; charset=utf8"
      end

      # @apidoc
      # Test a provider implementation for a realm.
      #
      # @category Hermes/Public
      # @path /api/hermes/v1/:realm/test/:kind
      # @http POST
      # @example /api/hermes/v1/apdm/test/email
      # @required [String] realm The realm for the implementaton.
      # @required [String] kind The implementation kind: 'sms' or 'email'
      # @status 200 Provider is fine
      # @status 500 Provider unavailable
      post '/:realm/test/:kind' do |realm, kind|
        provider = @configuration.provider_for_realm_and_kind(realm, kind.to_sym)
        if provider.test!
          halt 200, "Provider is fine"
        else
          halt 500, "Provider unavailable"
        end
      end

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
        message = nil
        begin
          message = Message.get(realm, uid)
        rescue => e
          logger.exception e if logger.respond_to?(:exception)
          return halt 500, "Could not get message, inspect logs"
        end
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

        provider = @configuration.provider_for_realm_and_kind(realm, kind.to_sym)

        message = message_from_params(params.except(:path))

        raw_message = message.dup
        raw_message.delete(:callback_url)
        raw_message[:receipt_url] = receipt_url(realm, kind.to_sym)

        if @configuration.actual_sending_allowed?(realm) or params[:force]
          if params[:force]
            raw_message[:recipient_email] = params[:force] if kind == "email"
            raw_message[:recipient_number] = params[:force] if kind == "sms"
          end
          id = provider.send_message!(raw_message)
          external_id = Message.build_external_id(provider, id)
        else
          external_id = Message.build_external_id(provider, Time.now.to_i.to_s)
          logger.warn("Actual sending is not performed in #{ENV['RACK_ENV']} environment. " \
            "Simulating external_id #{external_id} from provider")
        end

        begin
          post = pebblebed_connector(realm, current_identity).grove.post(
            "/posts/post.hermes_message:" + [realm, params[:path]].compact.join('.'),
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
          logger.info("Sent message (#{kind} via #{provider.class.name}): #{json_data}")
          halt 200, json_data
        end
      end

      # @apidoc
      # Endpoint for providers to callback the message status. This is a enpoint that
      # is used internally by Hermes, and not part of the public API.
      # When implementing new providers, you set up the provider service to do callbacks
      # of message statuses to this endpoint. Each provider implements it own parameters,
      # this is done with `provider.parse_receipt`, specifically implemented for each
      # provider.
      #
      # @category Hermes/Private
      # @path /api/hermes/v1/:realm/receipt/:kind
      # @http POST
      # @example /api/hermes/v1/apdm/receipt/email
      # @required [String] realm The realm sending messages for.
      # @required [String] kind The kind of message, 'email', 'sms'
      # @status 200
      post '/:realm/receipt/:kind' do |realm, kind|
        provider = @configuration.provider_for_realm_and_kind(realm, kind)
        raw = request.env['rack.input'].read if request.env['rack.input']
        raw ||= ''
        begin
          result = provider.parse_receipt(request.path_info, raw, params)
        rescue Exception => e
          logger.error("Ignoring exception during receipt parsing: #{e}")
        else
          if result[:id] and result[:status]
            message = Message.find_by_external_id(Message.external_id_prefix(provider) << result[:id], realm)
            if message
              message.add_tag!(result[:status])
            end
          end
        end
        ''
      end

      helpers do

        def message_from_params(params)
          hash = {
            recipient_number: params['recipient_number'],
            sender_number: params['sender_number'],
            recipient_email: params['recipient_email'],
            sender_email: params['sender_email'],
            subject: params['subject'],
            text: params['text'],
            html: params['html'],
            callback_url: params['callback_url']
          }
          if params['rate']
            hash[:rate] = {
              currency: (params['rate'])['currency'],
              amount: (params['rate'])['amount']
            }
          end
          hash.select { |k, v| !v.blank? }
        end

        def pebblebed_connector(realm, checkpoint_identity)
          if realm == checkpoint_identity.realm
            Pebblebed::Connector.new(@configuration.session_for_realm(realm))
          else
            raise ArgumentError, "Wrong realm #{realm.inspect}"
          end
        end

        def logger
          LOGGER
        end

        def receipt_url(realm, kind)
          # FIXME: Make configurable
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

  end
end

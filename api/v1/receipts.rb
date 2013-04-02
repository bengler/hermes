# encoding: utf-8

module Hermes
  class V1 < Sinatra::Base

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
      do_receipt(realm, kind, request, params)
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
    # @http GET
    # @example /api/hermes/v1/apdm/receipt/email
    # @required [String] realm The realm sending messages for.
    # @required [String] kind The kind of message, 'email', 'sms'
    # @status 200
    get '/:realm/receipt/:kind' do |realm, kind|
      do_receipt(realm, kind, request, params)
    end

    private

      def do_receipt(realm, kind, request, params)
        realm, provider = realm_and_provider(realm, kind)

        if (stream = request.env['rack.input'])
          raw = stream.read
        end

        begin
          result = provider.parse_receipt(request.path_info, raw,
            params.with_indifferent_access)
        rescue => e
          logger.error("Ignoring exception during receipt parsing: #{e}")
        else
          logger.info("Receipt status: #{result.inspect}")
          if result[:id] and result[:status]
            if (message = Message.find_by_external_id(
              Message.build_external_id(provider, result[:id]), realm.name))
              message.add_tag!(result[:status])
            end
          end
        end

        if provider.respond_to?(:ack_receipt)
          provider.ack_receipt(result, self)
        end

        halt 200, ''
      end

  end
end
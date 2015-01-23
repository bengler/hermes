# encoding: utf-8

module Hermes
  class V1 < Sinatra::Base

    # @apidoc
    # Receive an incoming message. All parameters to this method are provider-specific.
    #
    # @category Hermes/Receiving
    # @path /api/hermes/v1/:realm/incoming/:kind
    # @http GET
    get '/:realm/incoming/:kind' do |realm_name, kind|
      do_incoming(realm_name, kind)
    end

    # @apidoc
    # Receive an incoming message. All parameters to this method are provider-specific.
    #
    # @category Hermes/Receiving
    # @path /api/hermes/v1/:realm/incoming/:kind
    # @http POST
    post '/:realm/incoming/:kind' do |realm_name, kind|
      do_incoming(realm_name, kind)
    end


    private

      def do_incoming(realm_name, kind)
        realm = CONFIG.realm(realm_name)
        provider = realm.provider(kind)

        unless provider.respond_to?(:parse_message)
          halt 400, "Provider does not support handling incoming messages"
        end
        message = provider.parse_message(request)
        if message.present?
          logger.info("Received message via #{provider.class.name} (#{kind}): #{message.inspect}")

          external_id = Message.build_external_id(provider, message[:id])

          grove_key = "post.hermes_message:#{realm.name}.#{realm.grove_path}"

          if (binary = message[:binary]) && binary[:transfer_encoding] == :raw
            binary[:value] = Base64.encode64(binary[:value])
            binary[:transfer_encoding] = :base64
          end

          post = realm.pebblebed_connector.grove.post("/posts/#{grove_key}",
            post: {
              document: message.merge(kind: kind),
              restricted: true,
              tags: ["received"],
              external_id: external_id
            })

          if (url = realm.incoming_url)
            logger.info "Posting incoming message to #{url}"
            Http.perform_with_retrying(url) do |connection|
              connection.post(query: {
                uid: post['post']['uid']
              })
            end
          end

          if provider.respond_to?(:ack_message)
            provider.ack_message(message, self)
          end

          ''
        end
      end

  end
end

# encoding: utf-8

module Hermes
  class V1 < Sinatra::Base

    # @apidoc
    # Receive an incoming message. All parameters to this method are provider-specific.
    #
    # @category Hermes/Receiving
    # @path /api/hermes/v1/:realm/incoming/:kind
    # @http GET
    get '/:realm/incoming/:kind' do |realm, kind|
      do_incoming(realm, kind)
    end

    # @apidoc
    # Receive an incoming message. All parameters to this method are provider-specific.
    #
    # @category Hermes/Receiving
    # @path /api/hermes/v1/:realm/incoming/:kind
    # @http POST
    post '/:realm/incoming/:kind' do |realm, kind|
      do_incoming(realm, kind)
    end

    private

      def do_incoming(realm_name, kind)
        realm, provider = realm_and_provider(realm_name, kind)
        unless provider.respond_to?(:parse_message)
          halt 400, "Provider does not support handling incoming messages"
        end
        message = provider.parse_message(request)
        if message.present?
          logger.info("Received message via #{provider.class.name} (#{kind}): #{message.inspect}")

          external_id = Message.build_external_id(provider, message[:id])

          grove_key = "post.hermes_message:#{realm.name}.#{realm.grove_path}"

          post = realm.pebblebed_connector.grove.post("/posts/#{grove_key}",
            post: {
              document: message.merge(kind: kind),
              restricted: true,
              tags: ["received"],
              external_id: external_id
            })

          if realm.incoming_url
            Excon.new(realm.incoming_url).post(query: {
              uid: post['post']['uid']
            })
          end
        end
      end

  end
end
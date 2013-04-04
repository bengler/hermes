require 'delegate'
require 'deepstruct'

require 'pebbles-uid'

module Hermes
  class Message < SimpleDelegator

    VALID_STATUSES = [
      :failed,
      :inprogress,
      :delivered,
      :unknown
    ].freeze

    def add_tag!(tag)
      old_tags = self.tags
      new_tags = Hermes::Message.grove(Pebbles::Uid.new(self['uid']).realm).
        post("/posts/#{self['uid']}/tags/#{tag}")['post']['tags']
      the_tags = new_tags.to_a-old_tags.to_a
      notify_callback_url(the_tags.first) if the_tags.any?
    end

    def failed?
      tags.include?('failed') and !tags.include?('delivered')
    end

    def delivered?
      tags.include?('delivered')
    end

    def tags
      self['tags'] || []
    end

    def self.find(realm, uid)
      result = new(grove(realm).get("/posts/#{uid}"))
      return result['post'] || result['posts'] || []
    end

    def self.get(realm, uid)
      begin
        message = new(grove(realm).get("/posts/#{uid}"))['post']
      rescue Pebblebed::HttpNotFoundError
        return nil
      end
    end

    def self.find_by_external_id(id, realm)
      begin
        message = new(grove(realm).get("/posts/*", :external_id => id)['post'])
      rescue Pebblebed::HttpNotFoundError
        return nil
      end
    end

    def self.build_external_id(provider, content)
      "#{provider.class.name.underscore.split('/').last}_id:#{content}"
    end

    def self.grove(realm_name)
      Pebblebed::Connector.new(
        Hermes::Configuration.instance.realm(realm_name).session_key, HostContext.host).grove
    end

    private

      def callback_url
        self['document']['callback_url']
      end

      # TODO: Schedule asynchronously using AMQP
      def notify_callback_url(status)
        if callback_url
          uri = URI.parse(callback_url)
          uri.query << '&' if uri.query
          uri.query ||= ''
          uri.query << "status=#{status}"
          LOGGER.info("Notifying callback #{uri}")
          begin
            Timeout.timeout(10) do
              Excon.post(uri.to_s)
            end
          rescue Exception => e
            LOGGER.error("Callback failed: #{uri}: #{e.class}: #{e.message}")
          end
        end
        true
      end

  end
end

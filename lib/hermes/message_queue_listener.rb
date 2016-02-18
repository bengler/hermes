#!/usr/bin/env ruby
require './config/environment.rb'

module Hermes

  # Listens for a new post.hermes_message, looks up provider,
  # dispatches, and updates the grove post with a tag reflecting new status
  class MessageQueueListener

    def call(message)
      handle(message.payload) if message.payload['event'] == 'create'
      nil
    end

    def handle(payload)
      post = payload['attributes'].deep_symbolize_keys
      post = fix_tags!(post)

      logger.info { "Handling message: #{post.inspect}" }

      return if post[:tags].include? 'delivered'
      unless post[:tags].include? 'queued'
        logger.error("Message #{post[:uid]} not queued. That's odd.")
        return
      end

      message = post[:document].dup

      uid = Pebbles::Uid.new(post[:uid])
      return if uid.oid == '22040509' # quickfix

      realm = CONFIG.realm(uid.realm)

      provider = realm.provider(message[:kind])
      message.delete(:kind)
      message.delete(:batch_label)

      begin
        id = provider.send_message!(message)
      rescue ProviderError => e
        logger.error("Error: #{e.message} when trying to send: #{message}")
        post[:tags] << 'failed'
      else
        post[:tags] << 'inprogress'
        post[:external_id] = Message.build_external_id(provider, id)
      ensure
        grove_path = "/posts/#{post[:uid]}"
        begin
          realm.pebblebed_connector.grove.post(grove_path, post: post)
        rescue Pebblebed::HttpError => e
          if e.message.include? 'Post has been modified'
            # refetch
            message = Message.get(realm.name, post[:uid]).unwrap
            # uptdate tags
            message['tags'] = message['tags'].concat(post[:tags]).uniq
            # repost
            realm.pebblebed_connector.grove.post(grove_path, post: message)
          else
            logger.error("#{e.message} when trying to save post: #{message}")
          end
        end
      end
    end

    private

      def fix_tags!(post)
        tags = post[:tags_vector]
        tags = tags.split('\' \'').map{|t| t.gsub('\'','')}
        post[:tags] = tags
        post.delete(:tags_vector)
        post
      end

      def logger
        LOGGER
      end

  end

end

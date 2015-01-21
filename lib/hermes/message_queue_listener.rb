#!/usr/bin/env ruby
require './config/environment.rb'
require 'deepstruct'

module Hermes

  # Listens for a new post.hermes_message, looks up provider,
  # dispatches, and updates the grove post with a tag reflecting new status
  class MessageQueueListener

    def call(message)
      consider message.payload
      nil
    end


    def consider(payload)
      post = payload['attributes']
      post = fix_tags!(post)
      unless post['tags'].include? 'queued'
        LOGGER.error("Message #{post['uid']} not queued. That's odd.")
        return
      end

      message = post['document']
      realm = CONFIG.realm(Pebbles::Uid.new(post['uid']).realm)
      provider = realm.provider(message['kind'])

      begin
        id = provider.send_message!(message)
      rescue ProviderError
        post['tags'] << 'failed'
        raise
      else
        post['tags'] << 'inprogress'
        post['external_id'] = Message.build_external_id(provider, id)
      ensure
        grove_path = "/posts/#{post['uid']}"
        realm.pebblebed_connector.grove.post(grove_path, post: post)
      end
    end

    private

    def fix_tags!(post)
      tags = post['tags_vector']
      tags = tags.split('\' \'').map{|t| t.gsub('\'','')}
      post['tags'] = tags
      post.delete('tags_vector')
      post
    end

  end

end

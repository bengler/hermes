#!/usr/bin/env ruby
require './config/environment.rb'
require 'deepstruct'

module Hermes

  class MessageQueueListener

    def call(message)
      consider message.payload
      nil
    end

    # we only subscribe to new posts (event == 'create') so messages will only appear here once
    def consider(payload)
      post = payload['attributes']
      post = fix_tags!(post)
      unless post['tags'].include? 'queued'
        LOGGER.error("Message #{post['uid']} not queued. That's odd.")
        return
      end

      message = post['document'].dup
      message.delete('callback_url')

      realm_name = Pebbles::Uid.new(post['uid']).realm
      realm = CONFIG.realm(realm_name)
      provider = realm.provider(message['kind'])
      grove = realm.pebblebed_connector.grove
      grove_path = "/posts/#{post['uid']}"

      begin
        id = provider.send_message!(message)
      rescue ProviderError
        post['tags'] << 'failed'
        grove.post(grove_path, post: post)
        raise
      else
        post['tags'] << 'inprogress'
        post['external_id'] = Message.build_external_id(provider, id)
        grove.post(grove_path, post: post).to_json
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

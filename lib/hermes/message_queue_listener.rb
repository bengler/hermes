#!/usr/bin/env ruby
require './config/environment.rb'

module Hermes

  class MessageQueueListener

    def call(message)
      consider message.payload
      nil
    end

    def consider(payload)
      puts("Consider #{payload}")

      # raw_message.delete(:callback_url)
      #
      # begin
      #   id = @provider.send_message!(raw_message)
      # rescue ProviderError
      #   logger.info("Provider failed to send message (#{kind} via #{@provider.class.name}): #{message.inspect}")
      #   grove_post[:tags] = ['failed']
      #   pebblebed_connector(@realm, current_identity).grove.post(grove_path, post: grove_post)
      #   raise
      # else
      #   logger.info("Sent message (#{kind} via #{@provider.class.name}): #{message.inspect}")
      #   grove_post[:tags] = ['inprogress']
      #   grove_post[:external_id] = Message.build_external_id(@provider, id)
      #   pebblebed_connector(@realm, current_identity).grove.post(grove_path, post: grove_post).to_json
      # end
    end

  end

end

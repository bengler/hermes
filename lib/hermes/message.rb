module Hermes
  class Message < ActiveRecord::Base

    validates :realm, :presence => {}
    validates :vendor_id, :presence => {}
    validates :status, :presence => {}

    after_update :notify_callback_url

    private

      # TODO: Schedule asynchronously using AMQP
      def notify_callback_url
        if self.callback_url and status_changed?
          uri = URI.parse(self.callback_url)
          uri.query << '&' if uri.query
          uri.query ||= ''
          uri.query << "status=#{self.status}"
          logger.info("Notifying callback #{uri}")
          begin
            Timeout.timeout(10) do
              Excon.post(uri.to_s)
            end
          rescue Exception => e
            logger.error("Callback failed: #{uri}: #{e.class}: #{e.message}")
          end
        end
        true
      end

  end
end
module Hermes

  module Http

    class RedirectLoopError < StandardError
      def initialize(url)
        super("Redirect loop with resource #{url}")
        @url = url
      end
      attr_reader :url
    end

    def self.perform_with_retrying(url, &block)
      connection = Excon.new(url)

      retries_left, response, visited = 10, nil, Set.new
      begin
        begin
          Timeout.timeout(30) do
            if block
              response = block.call(connection)
            else
              response = connection.get
            end
            case response.status
              when 200..299
                return [response, true]
              when 301, 302
                location = URI.parse(response.headers['Location']) rescue nil
                if location and visited.add?(location)
                  url = location.to_s
                  next
                else
                  logger.error "Not following #{location}"
                  raise RedirectLoopError, location
                end
              when 502, 503, 504
                logger.warn "Resource #{url} failed with #{response.status}"
                sleep(1.0)
              else
                logger.error "Resource #{url} failed with #{response.status}"
                retries_left = 0
            end
          end
        rescue *EXCEPTIONS => e
          logger.warn "Resource #{url} failed with #{e.class}: #{e.message}"
          sleep(1.0)
          response = nil
        end

        retries_left -= 1
      end while retries_left > 0

      logger.error "Resource #{url} failed, giving up"
      [response, false]
    end

    private

      EXCEPTIONS = [
        Excon::Errors::SocketError,
        Timeout::Error
      ]

      def self.logger
        LOGGER
      end

  end
end
module Hermes

  class HostContext

    def self.with_host(host, &block)
      previous_host = Thread.current['pebble_context_host']
      Thread.current['pebble_context_host'] = host
      begin
        return yield
      ensure
        Thread.current['pebble_context_host'] = previous_host
      end
    end

    def self.host
      Thread.current['pebble_context_host']
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      HostContext.with_host(Rack::Request.new(env).host) do
        @app.call(env)
      end
    end

  end
end
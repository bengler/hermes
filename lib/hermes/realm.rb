# encoding: utf-8

module Hermes

  class ProviderNotFound < StandardError
    def initialize(realm, kind)
      super("No provider of kind '#{kind.inspect}' in realm #{realm.name}")
      @realm, @kind = realm, kind
    end

    attr_reader :realm, :kind
  end

  # Realm configuration.
  class Realm

    def initialize(name, options = {})
      options = options.symbolize_keys
      options.assert_valid_keys(
        :name, :session, :grove_path, :incoming_url, :implementations,
        :deny_actual_sending_from_environments)

      @name = name
      @session_key = options[:session]
      @grove_path = options[:grove_path]
      @incoming_url = options[:incoming_url]

      @perform_sending = !Array(options[:deny_actual_sending_from_environments]).
        include?(ENV['RACK_ENV'])

      @providers = {}
      (options[:implementations] || {}).each_pair do |kind, config|
        config, kind = config.symbolize_keys, kind.to_sym
        type = config.delete(:provider).try(:to_sym)
        begin
          klass = Hermes::Providers.const_get("#{type.to_s.classify}Provider")
        rescue NameError
          raise ProviderNotFound, type, kind
        else
          @providers[kind] = klass.new(config)
        end
      end
      @providers.freeze
    end

    def provider(kind)
      if @perform_sending
        kind = kind.to_sym
        provider = @providers[kind]
        unless provider
          raise ProviderNotFound.new(self, kind)
        end
      else
        logger.warn("Sending is disabled #{ENV['RACK_ENV']} environment, " \
          "will silently ignore outgoing messages.")
        provider = Providers::NullProvider.new
      end
      provider
    end

    attr_reader :name
    attr_reader :providers
    attr_reader :session_key
    attr_reader :grove_path
    attr_reader :incoming_url

    private

      def logger; LOGGER; end

  end

end
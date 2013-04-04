module Hermes

  class ProviderNotFound < StandardError
    def initialize(realm, kind)
      super("No provider of kind '#{kind.inspect}' in realm #{realm.name}")
      @realm, @kind = realm, kind
    end

    attr_reader :realm, :kind
  end

  class RealmNotFound < StandardError
    def initialize(name)
      super("Realm '#{name}' not found")
      @name = name
    end

    attr_reader :name
  end

  # Realm configuration.
  class Realm

    def initialize(name, options = {})
      options = options.symbolize_keys

      @name = name
      @session_key = options[:session]
      @receipt_url = options[:receipt_url]
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

    def perform_sending?
      @perform_sending
    end

    def provider(kind)
      kind = kind.to_sym
      if (provider = @providers[kind])
        return provider
      else
        raise ProviderNotFound.new(self, kind)
      end
    end

    attr_reader :name
    attr_reader :providers
    attr_reader :session_key
    attr_reader :receipt_url

  end

  class Configuration

    include Singleton

    def initialize
      @realms = {}
    end

    def load!(root = nil)
      @realms.clear

      if root.is_a?(String)
        root = Pathname.new(root)
      else
        root ||= Pathname.new(__FILE__).expand_path('../../..')
      end

      Pathname.glob(root.join('config/realms/*.yml')).each do |file_name|
        name = File.basename(file_name.to_s.gsub(/\.yml$/, ''))
        config = YAML.load(File.open(file_name, 'r:utf-8'))
        @realms[name] = Realm.new(name, config)
      end
    end

    def realm(name)
      if (realm = @realms[name])
        return realm
      else
        raise RealmNotFound, name
      end
    end

  end

end
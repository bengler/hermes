module Hermes

  class Configuration

    class ProviderNotFound < StandardError; end

    include Singleton

    def initialize
      @providers = {}
    end

    def load!(root_path = nil)
      @providers.clear
      root_path ||= File.expand_path('../../..', __FILE__)
      Dir.glob(File.join(root_path, 'config/realms/*.yml')).each do |file_name|
        realm = File.basename(file_name.gsub(/\.yml$/, ''))
        File.open(file_name) do |file|
          config = YAML.load(file).symbolize_keys
          provider_class = find_provider_class(config.delete(:provider))
          provider = provider_class.new(config)
          @providers[realm] = provider
        end
      end
    end

    def provider_for_realm(realm)
      @providers[realm] or raise ProviderNotFound.new(realm)
    end

    def find_provider_class(name)
      Hermes::Providers.const_get("#{name.to_s.classify}Provider")
    end

  end

end
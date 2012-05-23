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

      # Check realms/ for backwards compatibility.
      Dir.glob(File.join(root_path, 'config/{profiles,realms}/*.yml')).each do |file_name|
        profile = File.basename(file_name.gsub(/\.yml$/, ''))
        File.open(file_name) do |file|
          config = YAML.load(file).symbolize_keys
          provider_class = find_provider_class(config.delete(:provider))
          provider = provider_class.new(config)
          @providers[profile] = provider
        end
      end
    end

    def provider_for_profile(profile)
      @providers[profile] or raise ProviderNotFound.new(profile)
    end

    def find_provider_class(name)
      Hermes::Providers.const_get("#{name.to_s.classify}Provider")
    end

  end

end
module Hermes

  class OptionMissingError < Exception; end

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
          config = YAML.load(file)
          if config['sms']
            sms_provider_class = find_provider_class(config['sms'].delete('provider'))
            sms_provider = sms_provider_class.new(config['sms'].symbolize_keys)
          end
          if config['email']
            email_provider_class = find_provider_class(config['email'].delete('provider'))
            email_provider = email_provider_class.new(config['email'].symbolize_keys)
          end
          @providers[realm.to_sym] = {:session => config['session'], :sms => sms_provider, :email => email_provider}
        end
      end
    end

    def session_for_realm(realm)
      @providers[realm.to_sym][:session]
    end

    def provider_for_realm_and_kind(realm, kind)
      if @providers[realm.to_sym] and @providers[realm.to_sym][kind.to_sym]
        return @providers[realm.to_sym][kind.to_sym]
      end
      raise ProviderNotFound.new("A provider for '#{kind}' on realm '#{realm}' was not found.")
    end

    def find_provider_class(name)
      Hermes::Providers.const_get("#{name.to_s.classify}Provider")
    end

  end

end
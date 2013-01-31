module Hermes

  class OptionMissingError < Exception; end

  class Configuration

    class ProviderNotFound < StandardError; end
    class SessionNotFound < StandardError; end

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
          @providers[realm.to_sym] = {:session => config['session'], :deny_sending_from => config['deny_actual_sending_from_environments']}
          if config['implementations']
            config['implementations'].each do |k,v|
              provider_class = find_provider_class(config['implementations'][k].delete('provider'))
              provider = provider_class.new(config['implementations'][k].symbolize_keys)
              @providers[realm.to_sym].merge!(k.to_sym => provider)
            end
          end
        end
      end
    end

    def session_for_realm(realm)
      begin
        @providers[realm.to_sym][:session]
      rescue
        raise SessionNotFound.new("A session for realm '#{realm}' was not found.")
      end
    end

    def provider_for_realm_and_kind(realm, kind)
      if @providers[realm.to_sym] and @providers[realm.to_sym][kind.to_sym]
        return @providers[realm.to_sym][kind.to_sym]
      end
      raise ProviderNotFound.new("A provider for '#{kind}' on realm '#{realm}' was not found.")
    end

    def actual_sending_allowed?(realm)
      if @providers[realm.to_sym][:deny_sending_from]
       return !@providers[realm.to_sym][:deny_sending_from].include?(ENV['RACK_ENV'])
      end
      true
    end

    def find_provider_class(name)
      Hermes::Providers.const_get("#{name.to_s.classify}Provider")
    end

  end

end
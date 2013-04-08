# encoding: utf-8

module Hermes

  class RealmNotFound < StandardError
    def initialize(name)
      super("Realm '#{name}' not found")
      @name = name
    end

    attr_reader :name
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
        root ||= Pathname.new(__FILE__) + '../../..'
      end

      Pathname.glob(root.join('config/realms/*.yml')).each do |file_name|
        name = File.basename(file_name.to_s.gsub(/\.yml$/, ''))
        config = YAML.load(File.open(file_name, 'r:utf-8'))
        add_realm(name, Realm.new(name, config))
      end
    end

    def add_realm(name, realm)
      @realms[name] = realm
    end

    def realm(name)
      name = name.to_s
      if (realm = @realms[name])
        return realm
      else
        raise RealmNotFound, name
      end
    end

  end

end
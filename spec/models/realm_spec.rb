require 'spec_helper'

include WebMock::API
include Hermes

describe Realm do

  describe '#provider' do
    it 'returns null provider if environment disables sending' do
      realm = Realm.new('foo', {
        host: {'test' => 'example.org'},
        deny_actual_sending_from_environments: ENV['RACK_ENV']
      })
      realm.provider(:sms).should satisfy { |v|
        v.is_a?(Providers::NullProvider)
      }
      realm.provider(:email).should satisfy { |v|
        v.is_a?(Providers::NullProvider)
      }
    end
  end

end

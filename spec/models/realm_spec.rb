require 'spec_helper'

include WebMock::API
include Hermes

describe Realm do

  describe '#provider' do
    it 'returns null provider if environment disables sending' do
      realm = Hermes::Realm.new('foo', {
        deny_actual_sending_from_environments: ENV['RACK_ENV']
      })
      realm.provider(:sms).should satisfy { |v|
        v.is_a?(NullProvider)
      }
      realm.provider(:email).should satisfy { |v|
        v.is_a?(NullProvider)
      }
    end
  end

end
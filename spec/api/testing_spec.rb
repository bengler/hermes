require 'spec_helper'

include WebMock::API
include Hermes

describe 'Testing' do

  def app
    Hermes::V1
  end

  let :realm do
    Realm.new('test', {
      session: 'some_checkpoint_god_session_for_test_realm',
      implementations: {
        sms: {
          provider: 'Null'
        },
        email: {
          provider: 'Null'
        }
      }
    })
  end

  before :each do
    Configuration.instance.add_realm('test', realm)
  end

  %w(sms email).each do |kind|
    describe "POST /:realm/test/#{kind}" do

      it 'returns 200 when provider returns true' do
        Providers::NullProvider.any_instance.
          should_receive(:test!).
          with().
          once.
          and_return(true)
        post "/test/test/#{kind}"
        last_response.status.should == 200
      end

      it 'returns 500 when provider returns false' do
        Providers::NullProvider.any_instance.
          should_receive(:test!).
          with().
          once.
          and_return(false)
        post "/test/test/#{kind}"
        last_response.status.should == 500
      end

    end
  end

end

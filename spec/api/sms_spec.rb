require 'spec_helper'

include WebMock::API
include Hermes

describe 'SMS' do

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

  describe "POST /:realm/messages/sms" do

    it 'rejects unknown realm' do
      post "/doobie/messages/sms",
        recipient_number: '12345678',
        text: 'Yip'
      last_response.status.should == 404
    end

    it 'accepts message' do
      Providers::NullProvider.any_instance.
        should_receive(:send_message!).
        with(
          hash_including(
            recipient_number: '12345678',
            text: 'Yip')
        ).
        once.
        and_return("1234")

      post "/test/messages/sms",
        recipient_number: '12345678',
        text: 'Yip'
      last_response.status.should eq 200

      stub_grove_post!.should have_been_requested
    end

  end

end

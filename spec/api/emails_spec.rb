require 'spec_helper'

include WebMock::API
include Hermes

describe 'Email' do

  def app
    Hermes::V1
  end

  let :realm do
    Realm.new('test', {
      session: 'some_checkpoint_god_session_for_test_realm',
      implementations: {
        email: {
          provider: 'Null'
        }
      }
    })
  end

  before :each do
    Configuration.instance.add_realm('test', realm)
  end

  describe "POST /:realm/messages/email" do

    it 'accepts message' do
      NullProvider.any_instance.
        should_receive(:send_message!).
        with(
          hash_including(
            recipient_email: 'test@test.com',
            subject: "Foo",
            text: 'Yip',
            html: '<p>Yip</p>')
        ).
        once.
        and_return("1234")

      post "/test/messages/email", {
        :recipient_email => 'test@test.com',
        :subject => "Foo",
        :text => 'Yip',
        :html => '<p>Yip</p>'
      }
      last_response.status.should eq 200
      stub_grove_post!.should have_been_requested
    end

    it 'returns 400 on if recipient is rejected' do
      NullProvider.any_instance.
        should_receive(:send_message!) {
          raise RecipientRejectedError.new("test@test.com", "Is not valid")
        }.once

      post "/test/messages/email", {
        :recipient_email => 'test@test.com',
        :subject => "Foo",
        :text => 'Yip',
        :html => '<p>Yip</p>'
      }

      last_response.status.should eq 400
      last_response.body.should satisfy { |v|
        v =~ /is not valid/i
      }
    end

    it "supports test mode 'force'" do
      NullProvider.any_instance.
        should_receive(:send_message!).
        with(
          hash_including(
            recipient_email: 'jan@banan.com',
            subject: "Foo",
            text: 'Yip',
            html: '<p>Yip</p>')
        ).
        once.
        and_return("1234")

      post "/test/messages/email", {
        force: 'jan@banan.com',
        recipient_email: 'test@test.com',
        subject: "Foo",
        text: 'Yip',
        html: '<p>Yip</p>'
      }
      last_response.status.should eq 200
      stub_grove_post!.should have_been_requested
    end

  end

end
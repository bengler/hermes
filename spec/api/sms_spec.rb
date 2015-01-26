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
      host: {'test' => 'example.org'},
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

  let(:sms_params) {
    {
      recipient_number: '12345678',
      sender_number: '555',
      text: 'Yip'
    }
  }

  before :each do
    Configuration.instance.add_realm('test', realm)
    god!(:realm => 'test')
  end

  describe "POST /:realm/messages/sms" do

    it 'rejects unknown realm' do
      post "/doobie/messages/sms",
        recipient_number: '12345678',
        text: 'Yip'
      last_response.status.should == 404
    end

    it 'queues a message' do
      allow_any_instance_of(Pebblebed::GenericClient).to receive(:post) do |arg1, arg2|
        arg1.should eq '/posts/post.hermes_message:test'
        arg2[:post][:document][:recipient_number].should eq sms_params[:recipient_number]
        arg2[:post][:document][:sender_number].should eq sms_params[:sender_number]
        arg2[:post][:document][:text].should eq sms_params[:text]
        arg2[:post][:document][:kind].should eq 'sms'
        arg2[:post][:document][:receipt_url].should eq 'http://example.org:80/api/hermes/v1/test/receipt/sms'
        arg2[:post][:restricted].should be true
        arg2[:post][:tags].should eq ['queued']
      end

      post "/test/messages/sms", sms_params
      last_response.status.should eq 200
    end

    it 'supports rate param' do
      rate_params = {currency: 'NOK', amount: '10'}
      allow_any_instance_of(Pebblebed::GenericClient).to receive(:post) do |arg1, arg2|
        arg1.should eq '/posts/post.hermes_message:test'
        arg2[:post][:document][:rate].should eq rate_params
        arg2[:post][:tags].should eq ['queued']
      end

      post "/test/messages/sms", sms_params.merge(rate: rate_params)
      last_response.status.should eq 200
    end

  end

end

require 'spec_helper'

include WebMock::API
include Hermes

describe 'SMS' do

  def app
    Hermes::V1
  end

  describe "POST /:realm/messages/sms" do
    it 'rejects unknown realm' do
      post_body "/doobie/messages/sms", {}, JSON.dump(
        :recipient_number => '12345678',
        :text => 'Yip')
      last_response.status.should == 404
    end

    it 'accepts message' do
      post_body "/test/messages/sms", {}, JSON.dump(
        :recipient_number => '12345678',
        :text => 'Yip')
      last_response.status.should eq 200
      stub_grove_post!.should have_been_requested
    end

  end

end

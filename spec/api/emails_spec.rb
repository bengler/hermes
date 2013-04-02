require 'spec_helper'

include WebMock::API
include Hermes

describe 'Email' do

  def app
    Hermes::V1
  end

  describe "POST /:realm/messages/email" do
    it 'accepts message' do
      stub_mailgun_post!
      post "/test/messages/email", {
        :recipient_email => 'test@test.com',
        :subject => "Foo",
        :text => 'Yip',
        :html => '<p>Yip</p>'
      }
      stub_mailgun_post!.should have_been_requested
      last_response.status.should eq 200
      stub_grove_post!.should have_been_requested
    end
  end

end
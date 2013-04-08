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
      last_response.status.should eq 200
      stub_mailgun_post!.should have_been_requested
      stub_grove_post!.should have_been_requested
    end

    it 'returns 400 on if recipient is rejected' do
      stub_request(:post, "https://api:some_api_key_for_mailgun@api.mailgun.net/v2/some_domain_on_mailgun/messages").
        to_return(
          status: 400,
          body: {
            message: "'to' parameter is not a valid address, you dick.",
          }.to_json,
          headers: {'Content-Type' => 'application/json'})

      post "/test/messages/email", {
        :recipient_email => 'test@test.com',
        :subject => "Foo",
        :text => 'Yip',
        :html => '<p>Yip</p>'
      }
      last_response.status.should eq 400
      last_response.body.should satisfy { |v|
        v =~ /'to' parameter is not a valid address/
      }
    end

  end

end
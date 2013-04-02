require 'spec_helper'

include WebMock::API
include Hermes

describe 'Messages' do

  def app
    Hermes::V1
  end

  describe "GET /:realm/messages/:uid" do
    it "gives error if the realm is misconfigured" do
      get("/foo/messages/post.hermes_message:test$1234")
      last_response.status.should eq 500
    end

    it "returns a 404 if the post was not found" do
      get("/test/messages/post.hermes_message:test$4321")
      last_response.status.should eq 404
      stub_grove_get_post_failure!.should have_been_requested
    end

    it "returns the post if everything set up right" do
      get("/test/messages/post.hermes_message:test$1234")
      last_response.status.should eq 200
      JSON.parse(last_response.body)['uid'].should eq "post.hermes_message:test$1234"
      stub_grove_get_post_success!.should have_been_requested
    end
  end

  describe "Test modes" do
    it 'does not send when deny_actual_sending_from_environments is set for test env.' do
      Hermes::Configuration.instance.stub(:actual_sending_allowed?).and_return false
      post "/test/messages/email", {
        :recipient_email => 'test@test.com',
        :subject => "Foo",
        :text => 'Yip',
        :html => '<p>Yip</p>'
      }
      stub_mailgun_post!.should_not have_been_requested
      last_response.status.should eq 200
      stub_grove_post!.should have_been_requested
    end

    it "supports test mode 'force'" do
      Hermes::Configuration.instance.stub(:actual_sending_allowed?).and_return false
      stub_mailgun_force_post!
      post "/test/messages/email", {
        :force => 'jan@banan.com',
        :recipient_email => 'test@test.com',
        :subject => "Foo",
        :text => 'Yip',
        :html => '<p>Yip</p>'
      }
      stub_mailgun_force_post!.should have_been_requested
      last_response.status.should eq 200
      stub_grove_post!.should have_been_requested
    end
  end

end

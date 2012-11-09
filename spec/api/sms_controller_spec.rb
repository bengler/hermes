require 'spec_helper'

include WebMock::API
include Hermes

describe Hermes::V1::MessagesController do

  include Rack::Test::Methods

  before :each do
    Hermes::Configuration.instance.load!(File.expand_path('../..', __FILE__))
  end

  def app
    Hermes::V1::MessagesController
  end

  describe " > SMS functions > " do

    describe "POST /:realm/messages/sms" do
      it 'rejects unknown realm' do
        post_body "/doobie/messages/sms", {}, JSON.dump(
          :recipient_number => '12345678',
          :body => 'Yip')
        last_response.status.should == 404
      end

      it 'accepts message' do

        post_body "/test/messages/sms", {}, JSON.dump(
          :recipient_number => '12345678',
          :body => 'Yip')
        last_response.status.should eq 200
        stub_grove_post!.should have_been_requested
      end

    end

  end
end

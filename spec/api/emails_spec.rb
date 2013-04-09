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
      grove_post_stub = stub_request(:post, "http://example.org/api/grove/v1/posts/post.hermes_message:test").
        to_return(
          status: 200,
          body: {
            post: {
              uid: "post.hermes_message:test$1234",
              document: {
                body: "fofo",
                callback_url: "http://example.com/"
              },
              tags: ["in_progress"]
            }
          }.to_json)

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

      grove_post_stub.should have_been_requested
    end

    it 'returns 400 on if recipient is rejected' do
      grove_post_stub = stub_request(:post, "http://example.org/api/grove/v1/posts/post.hermes_message:test").
        to_return(
          status: 200,
          body: {
            post: {
              uid: "post.hermes_message:test$1234",
              document: {
                body: "fofo",
                callback_url: "http://example.com/"
              },
              tags: ["failed"]
            }
          }.to_json)

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

      grove_post_stub.should have_been_requested
    end

    it "supports test mode 'force'" do
      grove_post_stub = stub_request(:post, "http://example.org/api/grove/v1/posts/post.hermes_message:test").
        to_return(
          status: 200,
          body: {
            post: {
              uid: "post.hermes_message:test$1234",
              document: {
                body: "fofo",
                callback_url: "http://example.com/"
              },
              tags: ["in_progress"]
            }
          }.to_json)

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

      grove_post_stub.should have_been_requested
    end

  end

end
require 'spec_helper'

include WebMock::API
include Hermes

describe 'Messages' do

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
        }
      }
    })
  end

  before :each do
    Configuration.instance.add_realm('test', realm)
    god!(:realm => 'test')
  end

  describe "POST /:realm/messages/:kind" do

    it 'posts a message' do
      params = {
        sender_email: 'asdf@example.org',
        recipient_email: 'bling@blong.com',
        text: 'hello',
        path: 'test.email.bucket'
      }

      expected_post = {
        post: {
          document: {
            text: "hello",
            recipient_email: "bling@blong.com",
            sender_email: "asdf@example.org",
            receipt_url: "http://example.org:80/api/hermes/v1/test/receipt/email",
            kind: "email"
          },
          restricted: true,
          tags: ["queued"]
        }
      }
      Pebblebed::GenericClient.any_instance.should_receive(:post).with(
        '/posts/post.hermes_message:test.email.bucket',
        expected_post
      )
      post('/test/messages/email', params)

      expect(last_response).to have_media_type('application/json')
    end

  end

  describe "GET /:realm/messages/:uid" do

    it "returns 404 if the realm does not exist" do
      get("/foo/messages/post.hermes_message:test$1234")
      expect(last_response.status).to eq 404
      expect(last_response).to have_media_type('text/plain')
    end

    it "returns a 404 if the post was not found" do
      grove_get_stub = stub_request(:get, "http://example.org/api/grove/v1/posts/post.hermes_message:test$4321").
        with(
          query: hash_including(
            session: "some_checkpoint_god_session_for_test_realm"
          )
        ).
        to_return(status: 404)

      get("/test/messages/post.hermes_message:test$4321")

      expect(last_response.status).to eq 404
      expect(last_response).to have_media_type('text/plain')

      grove_get_stub.should have_been_requested
    end

    it "returns the post if everything set up right" do
      grove_get_stub = stub_request(:get, "http://example.org/api/grove/v1/posts/post.hermes_message:test$1234").
        with(
          query: hash_including(
            session: "some_checkpoint_god_session_for_test_realm"
          )
        ).to_return(
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

      get("/test/messages/post.hermes_message:test$1234")

      expect(last_response.status).to eq 200
      expect(last_response).to have_media_type('application/json')
      JSON.parse(last_response.body)['uid'].should eq "post.hermes_message:test$1234"

      grove_get_stub.should have_been_requested
    end

  end

end

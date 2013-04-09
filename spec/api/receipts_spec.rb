require 'spec_helper'

include WebMock::API
include Hermes

describe 'Receipts' do

  def app
    Hermes::V1
  end

  let :realm do
    Realm.new('test', {
      session: 'some_checkpoint_god_session_for_test_realm',
      implementations: {
        sms: {
          provider: 'Null'
        }
      }
    })
  end

  before :each do
    Configuration.instance.add_realm('test', realm)
  end

  describe "POST /:realm/receipt/:kind" do

    it "always accepts callback, as long as the realm is correct" do
      post_body "/test/receipt/sms", {}, %{I am test realm}
      last_response.status.should eq 200

      post_body "/meh/receipt/sms", {}, %{I am meh}
      last_response.status.should eq 404
    end

    it 'it updates message when a receipt is posted and performs callback' do
      grove_get_stub = stub_request(:get, "http://example.org/api/grove/v1/posts/*").
        with(
          query: hash_including(
            external_id: "null_provider_id:1234"
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

      grove_post_stub = stub_request(:post, "http://example.org/api/grove/v1/posts/post.hermes_message:test$1234/tags/delivered").
        with(
          body: {
            session: "some_checkpoint_god_session_for_test_realm"
          },
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json'
          }
        ).
        to_return(
          status: 200,
          body: {
            post: {
              uid: "post.hermes_message:test$1234",
              document: {
                body: "fofo",
                callback_url: "http://example.com/"
              },
              tags: ["in_progress", "delivered"]
            }
          }.to_json)

      callback_stub = stub_request(:post, "http://example.com/").
        with(
          query: hash_including(status: 'delivered')
        ).to_return(
          status: 200,
          body: '',
          headers: {})

      Providers::NullProvider.any_instance.
        should_receive(:parse_receipt).
        with(an_instance_of(Sinatra::Request)).
        once.
        and_return({id: "1234", status: "delivered"})

      Providers::NullProvider.any_instance.
        should_receive(:ack_receipt) { |params, controller|
          controller.halt 200, "OK"
        }.
        with(
          hash_including({id: "1234"}),
          an_instance_of(::Hermes::V1)
        ).
        once

      post_body "/test/receipt/sms", {}, "<something></something>"

      last_response.status.should eq 200
      last_response.body.should eq "OK"

      grove_get_stub.should have_been_requested
      grove_post_stub.should have_been_requested
      callback_stub.should have_been_requested  # FIXME: Not actually true!
    end
  end

end
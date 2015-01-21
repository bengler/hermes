require 'spec_helper'

include Hermes

describe 'MessageQueueListener' do

  subject {
    Hermes::MessageQueueListener.new
  }

  let(:uid) {
    'post.hermes_message:test.call.me$xyzzy'
  }

  let(:sms_payload) {
    {
      'attributes' => {
        'document' => {
          'sender_number' => "555-callme",
          'recipient_number' => "555-goaway",
          'text' => 'sup',
          'kind' => 'sms'
        },
        'uid' => uid,
        'restricted' => true,
        'tags_vector' => "'queued'"
      }
    }
  }

  context "incoming message" do

    it "is handled correctly" do
      expected_path = "/posts/#{uid}"
      expect_any_instance_of(Pebblebed::GenericClient).to receive(:post) do |path, hash|
        path.should eq expected_path
        hash[:post]['document'].should eq sms_payload['attributes']['document']
        hash[:post]['restricted'].should be true
        hash[:post]['tags'].should eq ["queued", "inprogress"]
      end
      subject.consider sms_payload
    end

  end

end

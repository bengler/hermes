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
      host: {'test' => 'example.org'},
      implementations: {
        email: {
          provider: 'Null'
        }
      }
    })
  end

  let :email_params do
    {
      recipient_email: 'test@test.com',
      sender_email: 'no-reply@test.com',
      bcc_email: 'secret@test.com',
      subject: 'Foo',
      text: 'Yip',
      html: '<p>Yip</p>'
    }
  end

  before :each do
    Configuration.instance.add_realm('test', realm)
    god!(:realm => 'test')
  end


  describe "POST /:realm/messages/email" do

    it 'queues a message' do
      allow_any_instance_of(Pebblebed::GenericClient).to receive(:post) do |arg1, arg2|
        arg1.should eq '/posts/post.hermes_message:test'
        arg2[:post][:document][:recipient_email].should eq 'test@test.com'
        arg2[:post][:document][:sender_email].should eq 'no-reply@test.com'
        arg2[:post][:document][:bcc_email].should eq 'secret@test.com'
        arg2[:post][:document][:subject].should eq 'Foo'
        arg2[:post][:document][:text].should eq 'Yip'
        arg2[:post][:document][:html].should eq '<p>Yip</p>'
        arg2[:post][:document][:kind].should eq 'email'
        arg2[:post][:document][:receipt_url].should eq 'http://example.org:80/api/hermes/v1/test/receipt/email'
        arg2[:post][:restricted].should be true
        arg2[:post][:tags].should eq ['queued']
      end

      post '/test/messages/email', email_params
      expect(last_response.status).to eq 200
      expect(last_response).to have_media_type('application/json')
    end

    it "supports force param" do
      allow_any_instance_of(Pebblebed::GenericClient).to receive(:post) do |arg1, arg2|
        arg1.should eq '/posts/post.hermes_message:test'
        arg2[:post][:document][:recipient_email].should eq 'jan@banan.com'
      end

      post '/test/messages/email', email_params.merge(force: 'jan@banan.com')
      expect(last_response.status).to eq 200
      expect(last_response).to have_media_type('application/json')
    end

    it 'supports batch_label param' do
      allow_any_instance_of(Pebblebed::GenericClient).to receive(:post) do |arg1, arg2|
        arg1.should eq '/posts/post.hermes_message:test'
        arg2[:post][:document][:batch_label].should eq 'stuff_sent_today'
      end

      post '/test/messages/email', email_params.merge(batch_label: 'stuff_sent_today')
      expect(last_response.status).to eq 200
      expect(last_response).to have_media_type('application/json')
    end

  end

end

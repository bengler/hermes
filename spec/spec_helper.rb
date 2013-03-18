ENV['RACK_ENV'] ||= 'test'
Bundler.require(:test)

# Simplecov must be loaded before everything else
require 'simplecov'
SimpleCov.add_filter 'spec'
SimpleCov.add_filter 'config'
SimpleCov.start

require File.expand_path('../../config/environment', __FILE__)

require 'rspec'
require 'rspec/autorun'
require 'rack/test'
require 'excon'
require 'webmock/rspec'
require 'stringio'
require 'pp'

set :environment, :test

LOGGER.level = Logger::FATAL

RSpec.configure do |config|
  config.before :each do
    WebMock.reset!
    stub_checkpoint_success!
    stub_mobiletech_success!
    stub_grove_update!
    stub_grove_post!
    stub_grove_get_post!
    stub_grove_update_success!
    stub_custom_callback_success!
    stub_grove_get_post_success!
    stub_grove_get_post_failure!
  end
end

def post_body(path, params, body, env = {})
  post(path, params, env.merge('rack.input' => StringIO.new(body)))
end

def pebbles_connector
  Pebblebed::Connector.new("some_checkpoint_god_session_for_test_realm")
end

def stub_mobiletech_success!
  stub_request(:post, 'http://msggw.dextella.net/BatchService').to_return(
    :body => %{
      <?xml version="1.0"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <soap:Body>
          <invokeBatchReply xmlns="http://mobiletech.com/dextella/msggw">
            <bid xmlns="http://batch.common.msggw.dextella.mobiletech.com">1</bid>
            <errorMessages xmlns="http://batch.common.msggw.dextella.mobiletech.com"/>
            <response xmlns="http://batch.common.msggw.dextella.mobiletech.com">SMS batch in progress. Await result report</response>
            <validBatch xmlns="http://batch.common.msggw.dextella.mobiletech.com">true</validBatch>
          </invokeBatchReply>
        </soap:Body>
      </soap:Envelope>
    })
end
def vanilla_sms_message
  '{"post": {"uid": "post.hermes_message:test$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}}, "tags": ["in_progress"] }'
end

def stub_grove_get_post!
  stub_request(:get, "http://hermes.dev/api/grove/v1/posts/post.hermes_message:test?session=some_checkpoint_god_session_for_test_realm").
           to_return(:status => 200, :body => vanilla_sms_message)
end

def stub_grove_post!
  stub_request(:post, "http://hermes.dev/api/grove/v1/posts/post.hermes_message:test").
    to_return(:status => 200, :body => vanilla_sms_message)
end

def stub_grove_update!
  stub_request(:post, "http://hermes.dev/api/grove/v1/posts/post.hermes_message:test$1234").
    with(:body => vanilla_sms_message)
end

def stub_checkpoint_success!
  stub_request(:get, "http://example.org/api/checkpoint/v1/identities/me?").
    to_return(:status => 200, :body => '{"identity":{"id":2751025,"god":true,"created_at":"2012-10-23T16:27:45+02:00","realm":"test","provisional":false,"fingerprints":["some_checkpoint_god_session_for_test_realm"]},"accounts":["facebook"],"profile":{"provider":"facebook","nickname":"skogsmaskin","name":"Per-Kristian Nordnes","profile_url":null,"image_url":"http://graph.facebook.com/552821200/picture?type=square","description":null}}', :headers => {})
end

def stub_grove_update_success!
  stub_request(:get, "http://hermes.dev/api/grove/v1/posts/*?external_id=mobiletech_provider_id:vroom&session=some_checkpoint_god_session_for_test_realm").
    to_return(:status => 200, :body => '{"post": {"uid": "post.hermes_message:test$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}, "tags": ["in_progress"]}}')
  stub_request(:post, "http://hermes.dev/api/grove/v1/posts/post.hermes_message:test$1234/tags/delivered").
  with(:body => "{\"session\":\"some_checkpoint_god_session_for_test_realm\"}", :headers => {'Accept'=>'application/json', 'Content-Type'=>'application/json'}).
      to_return(:status => 200, :body => '{"post": {"uid": "post.hermes_message:test$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}, "tags": ["in_progress", "delivered"]}}')
end

def stub_custom_callback_success!
  stub_request(:post, "http://example.com/?status=delivered").
     with(:headers => {'Host'=>'example.com:80'}).
     to_return(:status => 200, :body => "Roger that", :headers => {})
end

def stub_grove_get_post_success!
  stub_request(:get, "http://hermes.dev/api/grove/v1/posts/post.hermes_message:test$1234?session=some_checkpoint_god_session_for_test_realm").
    to_return(:status => 200, :body => vanilla_sms_message)
end

def stub_grove_get_post_failure!
  stub_request(:get, "http://hermes.dev/api/grove/v1/posts/post.hermes_message:test$4321?session=some_checkpoint_god_session_for_test_realm").
    to_return(:status => 404)
end

def stub_mailgun_post!
  stub_request(:post, "https://api:some_api_key_for_mailgun@api.mailgun.net/v2/some_domain_on_mailgun/messages").
           with(:body => {"from"=>"No-reply <no-reply@some_domain_on_mailgun>", "html"=>"<p>Yip</p>", "subject"=>"Foo", "text"=>"Yip", "to"=>"test@test.com"},
                :headers => {'Authorization'=>'Basic YXBpOnNvbWVfYXBpX2tleV9mb3JfbWFpbGd1bg==', 'Content-Type'=>'application/x-www-form-urlencoded'}).
           to_return(:status => 200, :body => '{"message": "Queued. Thank you.", "id": "<20111114174239.25659.5817@samples.mailgun.org>"}', :headers => {'Content-Type'=>'application/json'})
end

def stub_mailgun_force_post!
  stub_request(:post, "https://api:some_api_key_for_mailgun@api.mailgun.net/v2/some_domain_on_mailgun/messages").
           with(:body => {"from"=>"No-reply <no-reply@some_domain_on_mailgun>", "html"=>"<p>Yip</p>", "subject"=>"Foo", "text"=>"Yip", "to"=>"jan@banan.com"},
                :headers => {'Authorization'=>'Basic YXBpOnNvbWVfYXBpX2tleV9mb3JfbWFpbGd1bg==', 'Content-Type'=>'application/x-www-form-urlencoded'}).
           to_return(:status => 200, :body => '{"message": "Queued. Thank you.", "id": "<20111114174239.25659.5817@samples.mailgun.org>"}', :headers => {'Content-Type'=>'application/json'})
end

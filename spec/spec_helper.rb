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
  '{"post": {"uid": "post.sms:test$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}}, "tags": ["in_progress"] }'
end

def stub_grove_get_post!
  stub_request(:get, "http://hermes.dev/api/grove/v1/posts/post.sms:test?session=some_checkpoint_god_session_for_test_realm").
           to_return(:status => 200, :body => vanilla_sms_message)
end

def stub_grove_post!
  stub_request(:post, "http://hermes.dev/api/grove/v1/posts/post.sms:test").
    to_return(:status => 200, :body => vanilla_sms_message)
end

def stub_grove_update!
  stub_request(:post, "http://hermes.dev/api/grove/v1/posts/post.sms:test$1234").
    with(:body => vanilla_sms_message)
end

def stub_checkpoint_success!
  stub_request(:get, "http://example.org/api/checkpoint/v1/identities/me?").
    to_return(:status => 200, :body => '{"identity":{"id":2751025,"god":true,"created_at":"2012-10-23T16:27:45+02:00","realm":"test","provisional":false,"fingerprints":["some_checkpoint_god_session_for_test_realm"]},"accounts":["facebook"],"profile":{"provider":"facebook","nickname":"skogsmaskin","name":"Per-Kristian Nordnes","profile_url":null,"image_url":"http://graph.facebook.com/552821200/picture?type=square","description":null}}', :headers => {})
end

def stub_grove_update_success!
  stub_request(:get, "http://hermes.dev/api/grove/v1/posts?external_id=mobiletech_provider_id:vroom&session=some_checkpoint_god_session_for_test_realm").
    to_return(:status => 200, :body => '{"post": {"uid": "post.sms:test$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}, "tags": ["in_progress"]}}')
  stub_request(:put, "http://hermes.dev/api/grove/v1/posts/post.sms:test$1234").
    with(:body => "{\"document\":{\"tags\":[\"delivered\"]},\"session\":\"some_checkpoint_god_session_for_test_realm\"}").
      to_return(:status => 200, :body => '{"post": {"uid": "post.sms:test$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}, "tags": ["in_progress", "delivered"]}}')
end


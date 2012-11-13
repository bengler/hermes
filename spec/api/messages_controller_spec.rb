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

  post '/:realm/test/:kind' do |realm, kind|
    provider = @configuration.provider_for_realm_and_kind(realm, kind.to_sym)
    if provider.test!
      halt 200, "Provider is fine"
    else
      halt 500, "Provider unavailable"
    end
  end

  describe 'POST /:realm/test/:kind' do
    it 'returns 200 when provider for :kind is OK' do
      stub_request(:post, 'http://msggw.dextella.net/BatchService').to_return(
        :status => 200,
        :body => %{
          <?xml version="1.0"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <soap:Body>
              <invokeBatchReply xmlns="http://mobiletech.com/dextella/msggw">
                <bid xmlns="http://batch.common.msggw.dextella.mobiletech.com">1</bid>
                <errorMessages xmlns="http://batch.common.msggw.dextella.mobiletech.com">
                  <string xmlns="http://mobiletech.com/dextella/msggw">Oops</string>
                </errorMessages>
                <response xmlns="http://batch.common.msggw.dextella.mobiletech.com">Danger, Will Robinson</response>
                <validBatch xmlns="http://batch.common.msggw.dextella.mobiletech.com">false</validBatch>
              </invokeBatchReply>
            </soap:Body>
          </soap:Envelope>
        })
      post '/test/test/sms'
      last_response.status.should == 200
    end
  end

  describe "POST /:realm/receipt/:kind" do
    it "always accepts callback, as long as the realm is correct" do
      post_body "/test/receipt/sms", {}, %{I am test realm}
      last_response.status.should eq 200
      post_body "/meh/receipt/sms", {}, %{I am meh}
      last_response.status.should eq 404
    end

    it 'it updates message when a receipt is posted and performs callback' do
      post_body "/test/receipt/sms", {}, %{
        <BatchReport>
          <CpId>something</CpId>
          <TransactionId>vroom</TransactionId>
          <MessageReports>
            <MessageReport>
              <MessageId>647863102</MessageId>
              <Recipient>12345678</Recipient>
              <Currency>NOK</Currency>
              <FinalStatus>true</FinalStatus>
              <PartCount>1</PartCount>
              <Price>0</Price>
              <StatusCode>200</StatusCode>
              <StatusMessage>OK</StatusMessage>
            </MessageReport>
          </MessageReports>
          <RelatedFragments>0</RelatedFragments>
          <RequestedAmount>1</RequestedAmount>
          <Successful>1</Successful>
          <Failed>0</Failed>
          <Unknown>0</Unknown>
        </BatchReport>
      }
      last_response.status.should eq 200
      stub_grove_update_success!.should have_been_requested
      callback_stub = stub_request(:post, "http://example.com/?status=delivered").
        with(:headers => {'Host'=>'example.com:80'}).
        to_return(:status => 200, :body => "", :headers => {})
      callback_stub.should have_been_requested
    end
  end


end

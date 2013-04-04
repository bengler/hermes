require 'spec_helper'

include WebMock::API
include Hermes

describe 'Receipts' do

  def app
    Hermes::V1
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
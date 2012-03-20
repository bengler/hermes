require 'spec_helper'

include WebMock::API
include Hermes

describe Hermes::V1::MessagesController do

  include Rack::Test::Methods

  around :each do |block|
    ActiveRecord::Base.transaction(&block)
  end

  before :each do
    Hermes::Configuration.instance.load!(File.expand_path('../..', __FILE__))
  end

  def app
    Hermes::V1::MessagesController
  end

  describe "POST /:realm" do
    it 'rejects unknown realm' do
      post_body "/doobie", {}, JSON.dump(
        :recipient_number => '12345678',
        :body => 'Yip')
      last_response.status.should == 404
    end

    it 'accepts message' do
      mobiletech_stub = stub_mobiletech_success!

      post_body "/test", {}, JSON.dump(
        :recipient_number => '12345678',
        :body => 'Yip')

      last_response.status.should == 202
      last_response.body.should =~ /\d+/
      
      mobiletech_stub.should have_requested(:post, 'http://msggw.dextella.net/BatchService')

      message = Message.where(:id => last_response.body).first
      message.should_not == nil
      message.status.should == 'in_progress'
      message.recipient_number.should == '12345678'
    end

    it 'accepts message with callback' do
      stub_mobiletech_success!

      callback_stub = stub_request(:post, 'http://example.com/').with(
        :query => {:status => 'failed'})

      post_body "/test", {}, JSON.dump(
        :recipient_number => '12345678',
        :body => 'Yip',
        :callback_url => 'http://example.com/')

      last_response.status.should == 202
      last_response.body.should =~ /\d+/
      last_response.headers['Content-Type'].should =~ /text\/plain/
      last_response.headers['Location'].should =~ /\/test\/#{Regexp.escape last_response.body}/

      message = Message.where(:id => last_response.body).first
      message.status = 'failed'
      message.save!

      callback_stub.should have_requested(:post, 'http://example.com/').with(
        :query => {:status => 'failed'})
    end

    it 'accepts message with failing callback' do
      stub_mobiletech_success!

      callback_stub = stub_request(:post, 'http://example.com/').
        with(:query => {:status => 'failed'}).
        to_return(lambda { |request|
          raise "Yip yip"
        })

      post_body "/test", {}, JSON.dump(
        :recipient_number => '12345678',
        :body => 'Yip',
        :callback_url => 'http://example.com/')

      last_response.status.should == 202
      last_response.body.should =~ /\d+/

      message = Message.where(:id => last_response.body).first
      message.status = 'failed'
      message.save!

      callback_stub.should have_requested(:post, 'http://example.com/').with(
        :query => {:status => 'failed'})
    end
  end

  describe "GET /:realm/:id" do
    it 'shows status for message' do
      message = Hermes::Message.create!(
        :vendor_id => 'vroom',
        :realm => 'test',
        :status => 'in_progress')
      get "/test/#{message.id}"
      last_response.status.should == 200
    end

    it 'returns 404 for non-existent message' do
      get "/test/23890428309494"
      last_response.status.should == 404
    end

    it 'returns 404 for non-existent realm' do
      message = Hermes::Message.create!(
        :vendor_id => 'vroom',
        :realm => 'test',
        :status => 'in_progress')
      get "/yipyip/#{message.id}"
      last_response.status.should == 404
    end
  end

  describe "POST /:realm/receipt" do
    it 'returns 200 even on bad data' do
      post_body "/test/receipt", {}, %{I am a banana}
      last_response.status.should == 200
    end

    it 'accepts Mobiletech receipt' do
      message = Hermes::Message.create!(
        :vendor_id => 'vroom',
        :realm => 'test',
        :status => 'in_progress')
      post_body "/test/receipt", {}, %{
        <BatchReport>
          <CpId>1234</CpId>
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
      last_response.status.should == 200
    end

    it 'returns 404 for non-existent message' do
      get "/test/23890428309494"
      last_response.status.should == 404
    end

    it 'returns 404 for non-existent realm' do
      message = Hermes::Message.create!(
        :vendor_id => 'vroom',
        :realm => 'test',
        :status => 'in_progress')
      get "/yipyip/#{message.id}"
      last_response.status.should == 404
    end
  end

  def post_body(path, params, body, env = {})
    post(path, params, env.merge('rack.input' => StringIO.new(body)))
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

end
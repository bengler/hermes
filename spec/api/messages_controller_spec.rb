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

  describe "GET /stats" do
    Message::VALID_STATUSES.each do |status|
      it "returns statistics for '#{status}'" do
        Message.destroy_all
        Message.create!(
          :vendor_id => 'test',
          :profile => 'test',
          :status => status,
          :recipient_number => '12345678')
        get "/test/stats"
        last_response.status.should == 200
        statistics = JSON.parse(last_response.body)
        statistics.should include('statistics')
        statistics['statistics'].should include('failed_count')
        statistics['statistics'].should include('delivered_count')
        statistics['statistics'].should include('in_progress_count')
        statistics['statistics'].should include('unknown_count')
        statistics['statistics']["#{status}_count"].should == 1
        (Message::VALID_STATUSES - [status]).each do |other_status|
          statistics['statistics']["#{other_status}_count"].should == 0
        end
      end
    end
  end

  describe "GET /:profile/stats" do
    Message::VALID_STATUSES.each do |status|
      it "returns statistics for '#{status}'" do
        Message.destroy_all
        Message.create!(
          :vendor_id => 'test',
          :profile => 'test',
          :status => status,
          :recipient_number => '12345678')
        get "/test/stats"
        last_response.status.should == 200
        statistics = JSON.parse(last_response.body)
        statistics.should include('statistics')
        statistics['statistics'].should include('failed_count')
        statistics['statistics'].should include('delivered_count')
        statistics['statistics'].should include('in_progress_count')
        statistics['statistics'].should include('unknown_count')
        statistics['statistics']["#{status}_count"].should == 1
        (Message::VALID_STATUSES - [status]).each do |other_status|
          statistics['statistics']["#{other_status}_count"].should == 0
        end
      end
    end
  end

  describe "POST /:profile/messages" do
    it 'rejects unknown profile' do
      post_body "/doobie/messages", {}, JSON.dump(
        :recipient_number => '12345678',
        :body => 'Yip')
      last_response.status.should == 404
    end

    it 'accepts message' do
      mobiletech_stub = stub_mobiletech_success!

      post_body "/test/messages", {}, JSON.dump(
        :recipient_number => '12345678',
        :body => 'Yip')

      last_response.status.should == 202
      last_response.body.should =~ /\d+/
      
      mobiletech_stub.should have_been_requested

      message = Message.where(:id => last_response.body).first
      message.should_not == nil
      message.status.should == 'in_progress'
      message.recipient_number.should == '12345678'
    end

    it 'accepts message with bill entity' do
      mobiletech_stub = stub_mobiletech_success!

      post_body "/test/messages", {}, JSON.dump(
        :recipient_number => '12345678',
        :body => 'Yip',
        :bill => 'Skrue McDuck')

      last_response.status.should == 202
      last_response.body.should =~ /\d+/

      mobiletech_stub.should have_been_requested

      message = Message.where(:id => last_response.body).first
      message.should_not == nil
      message.status.should == 'in_progress'
      message.recipient_number.should == '12345678'
      message.bill.should == 'Skrue McDuck'
    end

    it 'accepts message with callback' do
      stub_mobiletech_success!

      callback_stub = stub_request(:post, 'http://example.com/').with(
        :query => {:status => 'failed'})

      post_body "/test/messages", {}, JSON.dump(
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

      callback_stub.should have_been_requested
    end

    it 'accepts message with failing callback' do
      stub_mobiletech_success!

      callback_stub = stub_request(:post, 'http://example.com/').
        with(:query => {:status => 'failed'}).
        to_return(lambda { |request|
          raise "Yip yip"
        })

      post_body "/test/messages", {}, JSON.dump(
        :recipient_number => '12345678',
        :body => 'Yip',
        :callback_url => 'http://example.com/')

      last_response.status.should == 202
      last_response.body.should =~ /\d+/

      message = Message.where(:id => last_response.body).first
      message.status = 'failed'
      message.save!

      callback_stub.should have_been_requested
    end
  end

  describe "GET /:profile/messages/:id" do
    it 'shows status for message' do
      message = Hermes::Message.create!(
        :vendor_id => 'vroom',
        :profile => 'test',
        :status => 'in_progress')
      get "/test/messages/#{message.id}"
      last_response.status.should == 200
      result = JSON.parse(last_response.body)
      result.should include('message')
      result['message']['profile'].should == 'test'
      result['message']['status'].should == 'in_progress'
    end

    it 'returns 404 for non-existent message' do
      get "/test/messages/23890428309494"
      last_response.status.should == 404
    end

    it 'returns 404 for non-existent profile' do
      message = Hermes::Message.create!(
        :vendor_id => 'vroom',
        :profile => 'test',
        :status => 'in_progress')
      get "/yipyip/messages/#{message.id}"
      last_response.status.should == 404
    end
  end

  describe "POST /:profile/receipt" do
    it 'returns 200 even on bad data' do
      post_body "/test/receipt", {}, %{I am a banana}
      last_response.status.should == 200
    end

    it 'accepts Mobiletech receipt' do
      message = Hermes::Message.create!(
        :vendor_id => 'vroom',
        :profile => 'test',
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
  end

  describe 'POST /:profile/test' do
    it 'returns 200 when provider is OK' do
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
      post '/test/test'
      last_response.status.should == 200
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
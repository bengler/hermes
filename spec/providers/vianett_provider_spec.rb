require 'spec_helper'

include Hermes
include WebMock::API

describe Providers::VianettProvider do

  let :provider_class do
    Providers::VianettProvider
  end

  let :provider do
    provider_class.new(username: 'ding', password: 'bat')
  end

  describe "#initiailize" do

    it 'can be configured with minimal configuration' do
      provider_class.new(
        username: 'ding',
        password: 'bat')
    end

    it 'rejects required parameters' do
      -> { provider_class.new(username: 'ding') }.should raise_error(ConfigurationError)
      -> { provider_class.new(password: 'ding') }.should raise_error(ConfigurationError)
    end

    it 'rejects unknown parameters' do
      -> { provider_class.new(
        username: 'ding',
        password: 'bat',
        to_be_or_not_to_be: "that is the question")
      }.should raise_error(ArgumentError)
    end

  end

  describe "#default_sender" do

    it 'returns configured sender' do
      provider = provider_class.new(
        username: 'ding', password: 'bat', default_sender: {number: 'Boink'})
      provider.default_sender.should eq({number: 'Boink', type: :msisdn})
    end

  end

  describe '#send_message!' do
    it 'sends message and returns ID' do
      stub_request(:post, 'https://smsc.vianett.no/V3/CPA/MT/MT.ashx').
        with(
          query: hash_including(
            Tel: '1234',
            msg: 'Hello',
            username: 'ding',
            password: 'bat')
        ).to_return(
          status: 200,
          body: '<ack errorcode="200">OK</ack>')
      result = provider.send_message!(recipient_number: '1234', text: "Hello")
      result.class.should be String
      result.present?.should eq true
    end

    it 'translates server internal error to exception' do
      stub_request(:post, 'https://smsc.vianett.no/V3/CPA/MT/MT.ashx').
        with(
          query: hash_including(
            Tel: '1234',
            msg: 'Hello',
            username: 'ding',
            password: 'bat')
        ).to_return(
          status: 200,
          body: '<ack errorcode="5000" refno="1">Crash</ack>')
      -> {
        provider.send_message!(recipient_number: '1234', text: "Hello")
      }.should raise_error(GatewayError, 'Crash') { |e|
        e.should respond_to(:refno)
        e.refno.should == '1'

        e.should respond_to(:status_code)
        e.status_code.should == 5000

        e.should respond_to(:message)
        e.message.should == 'Crash'
      }
    end

    it 'translates server validation error to exception' do
      stub_request(:post, 'https://smsc.vianett.no/V3/CPA/MT/MT.ashx').
        with(
          query: hash_including(
            Tel: '1234',
            msg: 'Hello',
            username: 'ding',
            password: 'bat')
        ).to_return(
          status: 200,
          body: '<ack errorcode="105" refno="1">Denied</ack>')
      -> {
        provider.send_message!(recipient_number: '1234', text: "Hello")
      }.should raise_error(MessageRejectedError, "Denied") { |e|
        e.should respond_to(:refno)
        e.refno.should == '1'

        e.should respond_to(:status_code)
        e.status_code.should == 105

        e.should respond_to(:message)
        e.message.should == 'Denied'
      }
    end

    it 'rejects invalid message key' do
      -> {
        provider.send_message!(
          recipient_number: '1234', text: "Hello", ding: "bat")
      }.should raise_error(ArgumentError)
    end

    it 'rejects missing required fields' do
      -> {
        provider.send_message!(text: 'Hello')
      }.should raise_error(ArgumentError)
    end
  end

  describe '#parse_message' do

    it "rejects incomplete message" do
      original = {sourceaddr: '123', destinationaddr: '234', refno: '1', message: 'Hello'}
      original.keys.each do |key|
        -> {
          provider.parse_message(request_with_params(original.except(key)))
        }.should raise_error(InvalidMessageError)
      end
    end

    it 'parses SMS message' do
      message = provider.parse_message(request_with_params(
        sourceaddr: '123',
        destinationaddr: '345',
        refno: '1',
        message: 'Doink',
        operator: '1',
        retrycount: '0',
        prefix: ''))
      message.should eq({
        sender_number: '123',
        recipient_number: '345',
        id: '1',
        text: 'Doink',
        vendor: {
          refno: '1',
          operator: '1',
          retry_count: 0,
          prefix: ''
        },
        type: :sms
      })
    end

    it 'parses MMS message containing Base64 data' do
      message = provider.parse_message(request_with_params(
        sourceaddr: '123',
        destinationaddr: '345',
        refno: '1',
        mmsdata: Base64.encode64("\x01\x02"),
        operator: '1',
        retrycount: '0',
        prefix: ''))
      message.should eq({
        sender_number: '123',
        recipient_number: '345',
        id: '1',
        binary: {
          content_type: 'application/zip',
          value: "\x01\x02",
          transfer_encoding: :raw
        },
        vendor: {
          refno: '1',
          operator: '1',
          retry_count: 0,
          prefix: ''
        },
        type: :mms
      })
    end

    it 'parses MMS message containing URL' do
      mms_stub = stub_request(:get, 'http://example.org/mms.zip').
        to_return(
          status: 200,
          headers: {"Content-Type" => "application/zip"},
          body: "\x01\x02")

      message = provider.parse_message(request_with_params(
        sourceaddr: '123',
        destinationaddr: '345',
        refno: '1',
        mmsurl: "http://example.org/mms.zip",
        operator: '1',
        retrycount: '0',
        prefix: ''))
      message.should eq({
        sender_number: '123',
        recipient_number: '345',
        id: '1',
        binary: {
          content_type: 'application/zip',
          value: "\x01\x02",
          transfer_encoding: :raw
        },
        vendor: {
          refno: '1',
          operator: '1',
          retry_count: 0,
          prefix: ''
        },
        type: :mms
      })

      mms_stub.should have_been_requested
    end

    it 'raises exception on failure to fetch MMS data' do
      mms_stub = stub_request(:get, 'http://example.org/mms.zip').
        to_return(status: 500)

      -> {
        provider.parse_message(request_with_params(
          sourceaddr: '123',
          destinationaddr: '345',
          refno: '1',
          mmsurl: "http://example.org/mms.zip",
          operator: '1',
          retrycount: '0',
          prefix: ''))
      }.should raise_error(provider_class::CouldNotFetchMMSDataError)
    end

    it 'raises exception on redirect loop fetching MMS data' do
      mms_stub = stub_request(:get, 'http://example.org/mms.zip').
        to_return(status: 302, headers: {'Location' => 'http://example.org/mms.zip'})

      -> {
        provider.parse_message(request_with_params(
          sourceaddr: '123',
          destinationaddr: '345',
          refno: '1',
          mmsurl: "http://example.org/mms.zip",
          operator: '1',
          retrycount: '0',
          prefix: ''))
      }.should raise_error(provider_class::CouldNotFetchMMSDataError)
    end

  end

  describe '#ack_message' do

    it 'acks message' do
      controller = Object.new
      controller.stub(:halt) do |status, body|
        nil
      end
      controller.should_receive(:halt) { |status, body|
        status.should eq 200
        body.should =~ /.*<ack.*refno='1'.*errorcode='0'>.*<\/ack>/m
      }.once

      provider.ack_message({
        id: '1',
        vendor: {
          refno: '1',
        },
        sender_number: '12345678',
        recipient_number: '12345679',
        text: 'Hello'
      }, controller)
    end

  end

  describe '#parse_receipt' do

    it 'parses normal receipt' do
      receipt = provider.parse_receipt(request_with_params(
        refno: '1',
        requesttype: 'mtstatus',
        msgok: 'True',
        StatusDescription: 'It was delivered, yo',
        Status: 'DELIVERD',
        SentDate: '09.04.2013+19:42:44',
        OperatorID: '280',
        Msg: 'Blah',
        Tel: '12345678',
        FromAlpha: 'doink'))
      receipt.should eq({
        id: '1',
        status: :delivered
      })
    end

    it 'parses error receipt' do
      receipt = provider.parse_receipt(request_with_params(
        refno: '1',
        requesttype: 'mtstatus',
        msgok: 'False',
        ErrorDescription: 'The customer does not exist',
        ErrorCode: 'InvalidTel',
        SentDate: '09.04.2013+19:42:44',
        OperatorID: '280',
        Msg: 'Blah',
        Tel: '12345678',
        FromAlpha: 'doink'))
      receipt.should eq({
        id: '1',
        status: :failed,
        vendor_status: 'InvalidTel',
        vendor_message: 'The customer does not exist'
      })
    end

    it 'rejects invalid receipt' do
      -> {
        provider.parse_receipt(request_with_params(
          requesttype: 'doink'))
      }.should raise_error(InvalidReceiptError)
    end

  end

end
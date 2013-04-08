require 'spec_helper'

include Hermes::Providers
include WebMock::API

describe VianettProvider do

  let :provider do
    VianettProvider.new(username: 'ding', password: 'bat')
  end

  describe "#initiailize" do

    it 'can be configured with minimal configuration' do
      VianettProvider.new(
        username: 'ding',
        password: 'bat')
    end

    it 'rejects required parameters' do
      -> { VianettProvider.new(username: 'ding') }.should raise_error(ConfigurationError)
      -> { VianettProvider.new(password: 'ding') }.should raise_error(ConfigurationError)
    end

    it 'rejects unknown parameters' do
      -> { VianettProvider.new(
        username: 'ding',
        password: 'bat',
        to_be_or_not_to_be: "that is the question")
      }.should raise_error(ArgumentError)
    end

  end

  describe "#default_sender" do

    it 'returns configured sender' do
      provider = VianettProvider.new(
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

  describe '#parse_receipt' do
    it 'parses receipt'
    it 'rejects invalid receipt'
  end

end
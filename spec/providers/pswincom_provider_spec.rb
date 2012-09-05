require 'spec_helper'

include Hermes::Providers
include WebMock::API

describe PSWinComProvider do

  let :provider do
    PSWinComProvider.new(:user => 'foo', :password => 'bar')
  end

  describe "#send_short_message!" do

    it 'can be configured with minimal configuration' do
      provider = PSWinComProvider.new(:user => 'foo', :password => 'bar')
      provider.user.should == 'foo'
    end

    it 'rejects missing required user in configuration' do
      lambda { PSWinComProvider.new({:password => 'bar'}) }.should raise_error
    end

    it 'rejects missing required password in configuration' do
      lambda { PSWinComProvider.new({:user => 'foo'}) }.should raise_error
    end

    it "treats gateway response other than 0 as rejected by the server" do
      stub_request(:post, 'https://sms.pswin.com/http4sms/sendRef.asp').to_return(
        :body => '1\n')
      lambda {
        provider.send_short_message!(:recipient_number => '12345678', :body => 'test')
      }.should raise_error(PSWinComProvider::MessageRejectedError)
    end

    it "Returns a reference value if the message was sent" do
      stub_request(:post, 'https://sms.pswin.com/http4sms/sendRef.asp').to_return(
        :body => "0\nOK\n4A4B0034DB")
      provider.send_short_message!(:recipient_number => '12345678', :body => 'test').should == "4A4B0034DB"
    end

    [310, 312, 500].each do |status|
      it "translates gateway error #{status} into API failures" do
        stub_request(:post, 'https://sms.pswin.com/http4sms/sendRef.asp').to_return(
          :status => status)
        lambda {
          provider.send_short_message!(:recipient_number => '12345678', :body => 'test')
        }.should raise_error(PSWinComProvider::APIFailureError)
      end
    end

    [302, 202, 404].each do |status|
      it "treats gateway status #{status} as invalid responses" do
        stub_request(:post, 'https://sms.pswin.com/http4sms/sendRef.asp').to_return(
          :status => status)
        lambda {
          provider.send_short_message!(:recipient_number => '12345678', :body => 'test')
        }.should raise_error(PSWinComProvider::InvalidResponseError)
      end
    end

    it 'supports timeout' do
      stub = stub_request(:post, 'https://sms.pswin.com/http4sms/sendRef.asp').to_return(lambda { |request|
        sleep(1)
      })
      lambda {
        provider.send_short_message!(
          :recipient_number => '+4740471730', :body => 'test', :timeout => 0.1)
      }.should raise_error(Timeout::Error)
      stub.should have_requested(:post, 'https://sms.pswin.com/http4sms/sendRef.asp')
    end

  end

  describe '#parse_receipt' do

    it "rejects receipt with bad syntax" do
      lambda {
        provider.parse_receipt("/", "FOO=BAR")
      }.should raise_error(PSWinComProvider::InvalidReceiptError)
    end

    it "rejects receipt missing transaction ID" do
      lambda {
        provider.parse_receipt("/", "STATE=DELIVRD")
      }.should raise_error(PSWinComProvider::InvalidReceiptError)
    end

    it "parses success" do
      result = provider.parse_receipt("/", "ID=1&RCV=4795126548&REF=338166433&STATE=DELIVRD&DELIVERYTIME=2012.09.05+12%3a45%3a33")
      result[:id].should eq "338166433"
      result[:status].should == :delivered
    end

    it "parses failure" do
      result = provider.parse_receipt("/", "ID=1&RCV=4795126548&REF=338166433&STATE=FAILED&DELIVERYTIME=2012.09.05+12%3a45%3a33")
      result[:id].should eq "338166433"
      result[:status].should == :failed
    end

    it "parses unknown" do
      result = provider.parse_receipt("/", "ID=1&RCV=4795126548&REF=338166433&STATE=FOO&DELIVERYTIME=2012.09.05+12%3a45%3a33")
      result[:id].should eq "338166433"
      result[:status].should == :unknown
    end

    it "parses in progress" do
      result = provider.parse_receipt("/", "ID=1&RCV=4795126548&REF=338166433&STATE=UNDELIV&DELIVERYTIME=2012.09.05+12%3a45%3a33")
      result[:id].should eq "338166433"
      result[:status].should == :in_progress
    end

  end

end

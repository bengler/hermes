# encoding: UTF-8
require 'spec_helper'

include Hermes::Providers
include WebMock::API

describe MailGunProvider do

  let :provider do
    MailGunProvider.new(:api_key => 'foo', :mailgun_domain => 'test.com')
  end

  describe "#send_message!" do

    it 'can be configured with minimal configuration' do
      provider = MailGunProvider.new(:api_key => 'foo', :mailgun_domain => 'test.com')
      provider.api_key.should eq 'foo'
      provider.mailgun_domain.should eq 'test.com'
    end

    it 'rejects missing required api_key in configuration' do
      lambda { MailGunProvider.new({:subject => 'bar@foo.com'}) }.should raise_error
    end

    it "returns a reference value if the message was sent" do
      stub_request(:post, "https://api:foo@api.mailgun.net/v2/test.com/messages").
        with(:body => {"from"=>"No-reply <no-reply@test.com>", "html"=>"", "subject"=>"", "text"=>"test", "to"=>"foo@bar.com"},
             :headers => {'Authorization'=>'Basic YXBpOmZvbw==', 'Content-Type'=>'application/x-www-form-urlencoded'}).
          to_return(:status => 200, :body => {:message => "Queued. Thank you.", :id => "<20111114174239.25659.5817@test.com>"}.to_json, :headers => {})
      provider.send_message!(:recipient_email => 'foo@bar.com', :text => 'test').should == "<20111114174239.25659.5817@test.com>"
    end

    it 'supports timeout' do
      stub = stub_request(:post, 'https://api:foo@api.mailgun.net/v2/test.com/messages').to_return(lambda { |request|
        sleep(1)
      })
      lambda {
        provider.send_message!(:recipient_email => 'foo@bar.com', :text => 'test', :timeout => 0.1)
      }.should raise_error(Timeout::Error)
      stub.should have_requested(:post, 'https://api:foo@api.mailgun.net/v2/test.com/messages')
    end

  end

  # describe '#parse_receipt' do

  #   it "rejects receipt with bad syntax" do
  #     lambda {
  #       provider.parse_receipt("/", "FOO=BAR")
  #     }.should raise_error(PSWinComProvider::InvalidReceiptError)
  #   end

  #   it "rejects receipt missing transaction ID" do
  #     lambda {
  #       provider.parse_receipt("/", "STATE=DELIVRD")
  #     }.should raise_error(PSWinComProvider::InvalidReceiptError)
  #   end

  #   it "parses success" do
  #     result = provider.parse_receipt("/", "ID=1&RCV=4795126548&REF=338166433&STATE=DELIVRD&DELIVERYTIME=2012.09.05+12%3a45%3a33")
  #     result[:id].should eq "338166433"
  #     result[:status].should == :delivered
  #   end

  #   it "parses failure" do
  #     result = provider.parse_receipt("/", "ID=1&RCV=4795126548&REF=338166433&STATE=FAILED&DELIVERYTIME=2012.09.05+12%3a45%3a33")
  #     result[:id].should eq "338166433"
  #     result[:status].should == :failed
  #   end

  #   it "parses unknown" do
  #     result = provider.parse_receipt("/", "ID=1&RCV=4795126548&REF=338166433&STATE=FOO&DELIVERYTIME=2012.09.05+12%3a45%3a33")
  #     result[:id].should eq "338166433"
  #     result[:status].should == :unknown
  #   end

  #   it "parses in progress" do
  #     result = provider.parse_receipt("/", "ID=1&RCV=4795126548&REF=338166433&STATE=UNDELIV&DELIVERYTIME=2012.09.05+12%3a45%3a33")
  #     result[:id].should eq "338166433"
  #     result[:status].should == :in_progress
  #   end

  # end

end

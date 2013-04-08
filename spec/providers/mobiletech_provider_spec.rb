require 'spec_helper'

include Hermes::Providers
include WebMock::API

describe MobiletechProvider do

  let :provider do
    MobiletechProvider.new(:cpid => '1234', :secret => 'tjoms')
  end

  describe "#initialize" do

    it 'can be configured with minimal configuration' do
      provider = MobiletechProvider.new(:cpid => '1234', :secret => 'tjoms')
      provider.cpid.should == '1234'
    end

    it 'rejects missing required CPID in configuration' do
      lambda { MobiletechProvider.new({:secret => 'tjoms'}) }.should raise_error
    end

    it 'rejects missing required secret in configuration' do
      lambda { MobiletechProvider.new({:cpid => '1234'}) }.should raise_error
    end

  end

  describe "#send_message!" do

    it "treats gateway non-SOAP response as invalid responses" do
      stub_request(:post, 'http://msggw.dextella.net/BatchService').to_return(
        :body => 'YIP YIP YIP')
      lambda {
        provider.send_message!(:recipient_number => '12345678', :text => 'test')
      }.should raise_error(MobiletechProvider::InvalidResponseError)
    end

    it "treats gateway non-XML response as invalid responses" do
      stub = stub_request(:post, 'http://msggw.dextella.net/BatchService').to_return(
        :body => %{
          <?xml version="1.0"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <? x= '>
          </soap:Envelope>
        })
      lambda {
        provider.send_message!(:recipient_number => '12345678', :text => 'test')
      }.should raise_error(MobiletechProvider::InvalidResponseError)
    end

    [310, 312, 500].each do |status|
      it "translates gateway error #{status} into API failures" do
        stub_request(:post, 'http://msggw.dextella.net/BatchService').to_return(
          :status => status)
        lambda {
          provider.send_message!(:recipient_number => '12345678', :text => 'test')
        }.should raise_error(MobiletechProvider::APIFailureError)
      end
    end

    [302, 202, 404].each do |status|
      it "treats gateway status #{status} as invalid responses" do
        stub_request(:post, 'http://msggw.dextella.net/BatchService').to_return(
          :status => status)
        lambda {
          provider.send_message!(:recipient_number => '12345678', :text => 'test')
        }.should raise_error(MobiletechProvider::InvalidResponseError)
      end
    end

    it 'handles SOAP errors' do
      stub = stub_request(:post, 'http://msggw.dextella.net/BatchService').to_return(
        :status => 500,
        :body => %{
          <?xml version="1.0"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <soap:Body>
              <soap:Fault>
                <faultcode>soap:Client</faultcode>
                <faultstring>dadgummit!</faultstring>
              </soap:Fault>
            </soap:Body>
          </soap:Envelope>
        })
      lambda {
        provider.send_message!(:recipient_number => '12345678', :text => 'test')
      }.should raise_error(MobiletechProvider::APIFailureError, /dadgummit!/)
    end

    it 'handles error responses' do
      stub = stub_request(:post, 'http://msggw.dextella.net/BatchService').to_return(
        :body => %{
          <?xml version="1.0"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <soap:Body>
              <invokeBatchReply xmlns="http://mobiletech.com/dextella/msggw">
                <bid xmlns="http://batch.common.msggw.dextella.mobiletech.com">24809112</bid>
                <errorMessages xmlns="http://batch.common.msggw.dextella.mobiletech.com">
                  <ns1:string xmlns:ns1="http://mobiletech.com/dextella/msggw">No default text provided</ns1:string>
                </errorMessages>
                <response xmlns="http://batch.common.msggw.dextella.mobiletech.com">Batch request contains error</response>
                <validBatch xmlns="http://batch.common.msggw.dextella.mobiletech.com">false</validBatch>
              </invokeBatchReply>
            </soap:Body>
          </soap:Envelope>
        })
      lambda {
        provider.send_message!(:recipient_number => '12345678', :text => 'test')
      }.should raise_error(MobiletechProvider::MessageRejectedError, /No default text provided/)
      stub.should have_requested(:post, 'http://msggw.dextella.net/BatchService')
    end

    it 'raises error if response lacks validity flag' do
      stub = stub_request(:post, 'http://msggw.dextella.net/BatchService').to_return(
        :body => %{
          <?xml version="1.0"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <soap:Body>
              <invokeBatchReply xmlns="http://mobiletech.com/dextella/msggw">
              </invokeBatchReply>
            </soap:Body>
          </soap:Envelope>
        })
      lambda {
        provider.send_message!(:recipient_number => '12345678', :text => 'test')
      }.should raise_error(MobiletechProvider::InvalidResponseError)
      stub.should have_requested(:post, 'http://msggw.dextella.net/BatchService')
    end

    it 'sends batch SMS and returns ID' do
      stub = stub_request(:post, 'http://msggw.dextella.net/BatchService').to_return(
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
      
      id = provider.send_message!(
        :recipient_number => '12345678',
        :text => 'test',
        :sender_number => '12345678',
        :receipt_url => 'http://example.org/')
      id.should =~ /.+/
      
      stub.should have_requested(:post, 'http://msggw.dextella.net/BatchService').
        with { |request|
          got_doc = Nokogiri::XML(request.body)

          tid = got_doc.xpath("//bat:transId",
            {'bat' => 'http://batch.common.msggw.dextella.mobiletech.com'}).text

          digest = Digest::SHA1.new
          digest.update('1234')
          digest.update(tid)
          digest.update('http://example.org/')
          digest.update('tjoms')
          signature = Base64.encode64(digest.digest).strip

          expect_doc = Nokogiri::XML(%{
            <Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/" xmlns:msg="http://mobiletech.com/dextella/msggw" xmlns:bat="http://batch.common.msggw.dextella.mobiletech.com" xmlns:mes="http://message.common.msggw.dextella.mobiletech.com">
              <Header/>
              <Body>
                <msg:batchSmsRequest>
                  <bat:cpId>1234</bat:cpId>
                  <bat:defaultText>test</bat:defaultText>
                  <bat:messages>
                    <mes:SmsMessage>
                      <mes:msisdn>4712345678</mes:msisdn>
                    </mes:SmsMessage>
                  </bat:messages>
                  <bat:prefShortNbrs>
                    <mes:ShortNumber>
                      <mes:countryCode>NO</mes:countryCode>
                      <mes:shortNumber>12345678</mes:shortNumber>
                    </mes:ShortNumber>
                  </bat:prefShortNbrs>
                  <bat:msgPrice>
                    <mes:currency>NOK</mes:currency>
                    <mes:price>0</mes:price>
                  </bat:msgPrice>
                  <bat:responseUrl>http://example.org/</bat:responseUrl>
                  <bat:signature>#{signature}</bat:signature>
                  <bat:transId>#{tid}</bat:transId>
                </msg:batchSmsRequest>
              </Body>
            </Envelope>
          }, nil, nil, Nokogiri::XML::ParseOptions::NOBLANKS | Nokogiri::XML::ParseOptions::STRICT)
          got_doc.to_xml == expect_doc.to_xml
        }
    end

  end

  describe '#parse_receipt' do

    it "rejects receipt with bad XML syntax" do
      lambda {
        provider.parse_receipt("/", "<? x")
      }.should raise_error(MobiletechProvider::InvalidReceiptError)
    end

    it "rejects receipt from wrong CPID" do
      lambda {
        provider.parse_receipt("/", %{
          <BatchReport>
            <CpId>9999</CpId>
          </BatchReport>
        })
      }.should raise_error(MobiletechProvider::InvalidReceiptError)
    end

    it "rejects receipt missing transaction ID" do
      lambda {
        provider.parse_receipt("/", %{
          <BatchReport>
            <CpId>1234</CpId>
          </BatchReport>
        })
      }.should raise_error(MobiletechProvider::InvalidReceiptError)
    end

    it "rejects receipt missing counts" do
      lambda {
        provider.parse_receipt("/", %{
          <BatchReport>
            <CpId>1234</CpId>
            <TransactionId>SOME_UNIQUE_KEY</TransactionId>
          </BatchReport>
        })
      }.should raise_error(MobiletechProvider::InvalidReceiptError)
    end

    it "parses success" do
      result = provider.parse_receipt("/", %{
        <BatchReport>
          <CpId>1234</CpId>
          <TransactionId>SOME_UNIQUE_KEY</TransactionId>
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
      })
      result[:id].should == 'SOME_UNIQUE_KEY'
      result[:status].should == :delivered
    end

    it "parses failure" do
      result = provider.parse_receipt("/", %{
        <BatchReport>
          <CpId>1234</CpId>
          <TransactionId>SOME_UNIQUE_KEY</TransactionId>
          <MessageReports>
            <MessageReport>
              <MessageId>647863102</MessageId>
              <Recipient>12345678</Recipient>
              <Currency>NOK</Currency>
              <FinalStatus>true</FinalStatus>
              <PartCount>1</PartCount>
              <Price>0</Price>
              <StatusCode>500</StatusCode>
              <StatusMessage>Something went wrong</StatusMessage>
            </MessageReport>
          </MessageReports>
          <RequestedAmount>1</RequestedAmount>
          <Successful>0</Successful>
          <Failed>1</Failed>
          <Unknown>0</Unknown>
        </BatchReport>
      })
      result[:id].should == 'SOME_UNIQUE_KEY'
      result[:status].should == :failed
      result[:vendor_status].should == '500'
      result[:vendor_message].should == 'Something went wrong'
    end

    it "parses unknown" do
      result = provider.parse_receipt("/", %{
        <BatchReport>
          <CpId>1234</CpId>
          <TransactionId>SOME_UNIQUE_KEY</TransactionId>
          <RequestedAmount>1</RequestedAmount>
          <Successful>0</Successful>
          <Failed>0</Failed>
          <Unknown>1</Unknown>
        </BatchReport>
      })
      result[:id].should == 'SOME_UNIQUE_KEY'
      result[:status].should == :unknown
    end

    it "parses in progress" do
      result = provider.parse_receipt("/", %{
        <BatchReport>
          <CpId>1234</CpId>
          <TransactionId>SOME_UNIQUE_KEY</TransactionId>
          <RequestedAmount>1</RequestedAmount>
          <Successful>0</Successful>
          <Failed>0</Failed>
          <Unknown>0</Unknown>
        </BatchReport>
      })
      result[:id].should == 'SOME_UNIQUE_KEY'
      result[:status].should == :in_progress
    end

  end

end

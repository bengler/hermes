require 'spec_helper'

include WebMock::API
include Hermes

describe 'Testing' do

  def app
    Hermes::V1
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

end
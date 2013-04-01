require 'spec_helper'

include Hermes::Providers
include WebMock::API

describe VianettProvider do

  let :provider do
    VianettProvider.new(username: 'ding', password: 'bat')
  end

  describe "#initiailize" do

    it 'can be configured with minimal configuration' do
      provider = VianettProvider.new(
        username: 'ding', password: 'bat', default_sender: {number: 'Boink'})
      provider.default_sender[:number].should eq 'Boink'
    end

    it 'rejects required parameters' do
      -> { VianettProvider.new(username: 'ding') }.should raise_error(ConfigurationError)
      -> { VianettProvider.new(password: 'ding') }.should raise_error(ConfigurationError)
    end

  end

  describe '#send_message' do
    it 'sends message'
    it 'rejects invalid message'
  end

  describe '#parse_receipt' do
    it 'parses receipt'
    it 'rejects invalid receipt'
  end

end
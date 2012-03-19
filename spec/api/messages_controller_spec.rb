require 'spec_helper'

include WebMock::API

describe Hermes::V1::MessagesController do

  include Rack::Test::Methods

  before :each do
    Hermes::Configuration.instance.load!(File.expand_path('../..'))
  end

  def app
    Hermes::V1::MessagesController
  end

  it 'accepts message'

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
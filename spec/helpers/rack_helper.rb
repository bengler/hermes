require 'stringio'
require 'ostruct'

module RackHelper

  class FakeRequest < OpenStruct
  end

  def request_with_input_stream(content)
    request = FakeRequest.new
    request.env = {"rack.input" => StringIO.new(content)}
    request
  end

end
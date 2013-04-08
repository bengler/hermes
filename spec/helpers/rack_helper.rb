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

  def post_body(path, params, body, env = {})
    body = JSON.dump(body) if body.is_a?(Hash)
    post(path, params, env.merge('rack.input' => StringIO.new(body)))
  end

end
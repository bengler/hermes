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

  def request_with_params(params)
    query_string = params.entries.map { |(k, v)|
      "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"
    }.join('&')
    Rack::Request.new({
      'rack.input' => StringIO.new(''),
      'QUERY_STRING' => query_string
    })
  end

  def post_body(path, params, body, env = {})
    body = JSON.dump(body) if body.is_a?(Hash)
    post(path, params, env.merge('rack.input' => StringIO.new(body)))
  end

end
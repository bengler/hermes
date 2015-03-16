require 'stringio'
require 'ostruct'

module RackHelper

  class FakeRequest < OpenStruct
  end

  def self.extract_media_type(content_type_or_response)
    if content_type_or_response.respond_to?(:headers)
      content_type = content_type_or_response.headers['Content-Type'].to_s
    else
      content_type = content_type_or_response.to_s
    end

    # Poor man's MIME parser
    (content_type || '').split(';').map(&:strip).first
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

RSpec::Matchers.define :have_media_type do |expected|
  match do |actual|
    ::RackHelper.extract_media_type(actual) == expected
  end
  failure_message_for_should do |actual|
    actual_type = ::RackHelper.extract_media_type(actual)
    "expected response to have media type #{expected.inspect}, got #{actual_type.inspect}"
  end
end

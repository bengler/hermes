# encoding: utf-8

module Hermes
  class V1 < Sinatra::Base

    # @apidoc
    # Test a provider implementation for a realm.
    #
    # @category Hermes/Public
    # @path /api/hermes/v1/:realm/test/:kind
    # @http POST
    # @example /api/hermes/v1/apdm/test/email
    # @required [String] realm The realm for the implementaton.
    # @required [String] kind The implementation kind: 'sms' or 'email'
    # @status 200 Provider is fine
    # @status 500 Provider unavailable
    post '/:realm_name/test/:kind' do |realm_name, kind|
      headers 'Content-Type' => 'text/plain; charset=utf8'

      realm = CONFIG.realm(realm_name)

      provider = realm.provider(kind)
      if provider.test!
        success! message: "Provider is fine"
      else
        failure! message: "Provider unavailable", status: 500
      end
    end

  end
end

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
    post '/:realm/test/:kind' do |realm, kind|
      provider = @configuration.provider_for_realm_and_kind(realm, kind.to_sym)
      if provider.test!
        halt 200, "Provider is fine"
      else
        halt 500, "Provider unavailable"
      end
    end

  end
end
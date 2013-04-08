module Hermes

  # Base class for provider exceptions.
  class ProviderError < StandardError; end

  # Thrown when a receipt is invalid.
  class InvalidReceiptError < ProviderError; end

  # Unexpected gateway error.
  class GatewayError < ProviderError; end

  # An attempted message sending was rejected by the server.
  class MessageRejectedError < ProviderError; end

  # An exception thrown when the configuration is not valid.
  class ConfigurationError < ProviderError; end

  # An exception thrown when a server response was malformed.
  class InvalidResponseError < ProviderError; end

  # Invalid option to provider method.
  class OptionMissingError < ProviderError; end

  # Thrown when recipient is not valid.
  class RecipientRejectedError < ProviderError

    def initialize(recipient, reason)
      super("Recipient '#{recipient}' rejected: #{reason}")
      @recipient, @reason = recipient, reason
    end

    attr_reader :recipient, :reason

  end

end
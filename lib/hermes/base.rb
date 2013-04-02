module Hermes

  # Base class for provider exceptions.
  class ProviderError < StandardError; end

  # Thrown when a receipt is invalid.
  class InvalidReceiptError < ProviderError; end

  # An attempted message sending was rejected by the server.
  class MessageRejectedError < ProviderError; end

  # An exception thrown when the configuration is not valid.
  class ConfigurationError < ProviderError; end

  # An exception thrown when a server response was malformed.
  class InvalidResponseError < ProviderError; end

  # Invalid option to provider method.
  class OptionMissingError < ProviderError; end

end
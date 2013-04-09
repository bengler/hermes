# Provider interface

## Interface

Providers must support the following methods.

### Sending

*Required*. Sends messages to a single recipient.

```ruby
def send_message!(options)
```

The provider must return a single vendor-specific string key that can be used to query the status of a message delivery.

### Testing

*Required*.  Test whether the provider's connection is functional. Returns true or false.

```ruby
def test!
```

### Receipt parsing

*Optional*. This method must parse a receipt callback obtained from the provider.

```ruby
parse_receipt(rack_request)
```

It must return a hash:

* `:id` (required): The ID of the transaction, as returned by `send_message!`.
* `:status` (required): A symbol representing the current status, one of `:in_progress`, `:delivered`, `:unknown` or `:failed`.
* `:vendor_status`: Vendor-specific status code or string.
* `:vendor_message`: Optional human-readable explanation for the vendor status.

### Receipt acking

*Optional*. If the provider needs to respond to the receipt, then this method can be implemented.

```
ack_receipt(receipt_result, controller)
```

Here, `receipt_result` is the data returned from `parse_receipt`, and `controller` is the Sinatra controller.

### Incoming messages

*Optional*. This method must parse an incoming message obtained from the provider.

```ruby
parse_message(params, rack_request)
```

It must return a hash with data compatible with `send_message!`. Note that the ID returned in the `:id` key is a vendor-provided ID.

### Incoming message acking

*Optional*. If the provider needs to respond to the incoming message, then this method can be implemented.

```
ack_message(message, controller)
```

Here, `message` is the data returned from `parse_message`, and `controller` is the Sinatra controller.

## Providers

### Vianett

This provider supports the following configuration variables:

* `:username` (required): The CPID.
* `:password` (required): API secret.
* `:default_sender`: A hash of:
   * `:number`: Number of default sender.
   * `:type`: Either `:short_code`, `:alphanumeric` or `:msisdn` (default).
* `:default_prefix`: Prefix to use for numbers when no country prefix has been specified. Defaults to `47`.

### Mobiletech

*Deprecated, superceded by Vianett*. This provider supports the following configuration variables:

* `:cpid` (required): The CPID.
* `:secret` (required): API secret.
* `:sender_country`: Country code of sender. Defaults to `NO`.
* `:default_sender`: Sender number to use by default. Defaults to the nothing (ie., the gateway default).
* `:default_prefix`: Prefix to use for numbers when no country prefix has been specified. Defaults to `47`.

### PSWinCom

This provider supports the following configuration variables:

* `:user` (required): The PSWincom API user.
* `:password` (required): The PSWincom API password.
* `:default_sender_country`: Country code of sender. Defaults to `NO`.
* `:default_sender_number`: Sender number to use by default. Defaults to the nothing (ie., the gateway default).
* `:default_prefix`: Prefix to use for numbers when no country prefix has been specified. Defaults to `47`.

To administer the callback to Hermes, please log in to the account web on: https://accountweb.pswin.com/

Please note that the account must be enabled for the delivery reports
feature (callbacks) by PSWincom first! Otherwise you will get a invalid
response from the PSWinCom API, and no callback (even though messages are delivered).

### Mailgun

This provider supports the following configuration variables:

* `:api_key` (required): The Mailgun API-key.
* `:mailgun_domain` (required): The Mailgun Domain.
* `:default_sender_email`: The default sender email, if no sender is specified.

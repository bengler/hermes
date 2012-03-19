Messaging provider interface
============================

Interface
---------

Sending messages to a single recipient:

```ruby
send_short_message!(options)
```

Options must be a hash of the following:

* +:recipient+ (required): Recipient number. Either an unprefix number (12345678) or a prefixed number (+4712345678).
* +:body+: Body text.
* +:receipt_url+: the callback URL that the provider will ping with the delivery receipt.
* +:rate+: a hash:
  * +:currency+ (required): currency name, eg. USD.
  * +:amount+ (required): amount in that currency * 100. Eg., to specify 1 USD, specify `100`.
* +:sender+: the sender number or text. May not be supported by all providers.
* +:timeout+: timeout, in seconds, for the sending to complete.

The provider must return a vendor-specific string key that can be used to query the status of a message delivery.

```
parse_receipt(url, raw_body)
```

This method must parse a receipt callback. It must return a hash:

* +:id+ (required): The ID of the transaction, as returned by `send_short_message!`.
* +:status+ (required): A symbol representing the current status, one of +:in_progress+, +:delivered+, +:unknown+ or +:failed+.
* +:vendor_status+: Vendor-specific status code or string.
* +:vendor_message+: Optional human-readable explanation for the vendor status.

Mobiletech
----------

This provider requires the following configuration:

* +:cpid+ (required): The CPID.
* +:secret+ (required): API secret.
* +:sender_country+: Country code of sender. Defaults to `NO`.
* +:default_sender+: Sender number to use by default.
* +:default_prefix+: Prefix to use for numbers when no country prefix has been specified. Defaults to `47`.

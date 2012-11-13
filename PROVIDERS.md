Messaging provider interface
============================

Interface
---------

Sending messages to a single recipient:

```ruby
send_message!(options)
```

The provider must return a vendor-specific string key that can be used to query the status of a message delivery.

```ruby
test!
```

Test whether the provider's connection is functional. Returns true or false.

```ruby
parse_receipt(url, raw_body, params)
```

This method must parse a receipt callback. It must return a hash:

* `:id` (required): The ID of the transaction, as returned by `send_short_message!`.
* `:status` (required): A symbol representing the current status, one of `:in_progress`, `:delivered`, `:unknown` or `:failed`.
* `:vendor_status`: Vendor-specific status code or string.
* `:vendor_message`: Optional human-readable explanation for the vendor status.

Mobiletech
----------

This provider supports the following configuration variables:

* `:cpid` (required): The CPID.
* `:secret` (required): API secret.
* `:sender_country`: Country code of sender. Defaults to `NO`.
* `:default_sender`: Sender number to use by default. Defaults to the nothing (ie., the gateway default).
* `:default_prefix`: Prefix to use for numbers when no country prefix has been specified. Defaults to `47`.

PSWinCom
----------

This provider supports the following configuration variables:

* `:user` (required): The PSWincom API user.
* `:password` (required): The PSWincom API password.
* `:default_sender_country`: Country code of sender. Defaults to `NO`.
* `:default_sender_number`: Sender number to use by default. Defaults to the nothing (ie., the gateway default).
* `:default_prefix`: Prefix to use for numbers when no country prefix has been specified. Defaults to `47`.

To administer the callback to Hermes, please log in to the account web on: https://accountweb.pswin.com/
PS: Please note that the account must be enabled for the delivery reports
feature (callbacks) by PSWincom first! Otherwise you will get a invalid
response from the PSWinCom API, and no callback (even though messages are delivered).


Mailgun
----------

This provider supports the following configuration variables:

api_key: key-8xybyxgfrbgmeg82mfzplrcux6cxg4o8
mailgun_domain: dna.mailgun.org

* `:api_key` (required): The Mailgun API-key.
* `:mailgun_domain` (required): The Mailgun Domain.
* `:default_sender_email`: The default sender email, if no sender is specified.

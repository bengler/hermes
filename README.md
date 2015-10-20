Hermes
======

Hermes is the god of external message delivery. It acts as a facade in front of multiple providers that implement SMS and email delivery.

## Grove

Messages are stored as restricted Grove posts (`post.hermes_message`) that are only accessible with a god session in the realm.

## Configuration

Before one can send a message, one or more realms must be configured. Configuration files are located in `config/realms` and must use the YAML format. For example, `config/realms/foo.yml` defines settings for the `foo` realm.

### Example

Let's configure the realm `test`.

Create the file `config/realms/test.yml` with the content:

  ```
  session: hermesapplicationfb8f11fjeiwjoefijwe40e82efa7d3895954b4537317689a0960e35c67076
  deny_actual_sending_from_environments:
    - staging
  implementations:
    sms:
      provider: PSWinCom
      user: test
      password: myPassword
      default_sender_country: NO
      default_sender_number: Test
      default_prefix: 47
    email:
      provider: MailGun
      api_key: key-2340i230+4230423094i3
      mailgun_domain: test.mailgun.org
  ```

The ``session`` key must be a god session that matches the realm in Checkpoint.

See [this reference](./PROVIDERS.md) for details about available providers for the `sms` and `email` keys.

### Mailgun

The `mailgun` provider has these options:

* `api_key`: The API key.
* `mailgun_domain`: Optional. This domain will be used if a sender address does not match any domain in the Mailgun account. The provider will first attempt to use the sender email's domain, and fall back to this domain. (Note that if a send fails with the sender's domain, the provider will not retry for another minute, but will continue to use the `mailgun_domain` setting as a fallback.) Normally, it should not be necessary to set this option.

## Sending messages

With the example above, it's possible to send SMS and email for the `test` realm. We may then post messages with the API, via `POST` requests:

### Email

To send email, `POST` to `/api/hermes/v1/test/messages/email`. With the [pebblebed](//github.com/bengler/pebblebed) gem:

```ruby
connector.hermes.post("/endeavor/messages/email", {
  recipient_email: 'foo@example.com',
  sender_email: 'no-reply@example.org',
  bcc_email: 'secret@example.org',
  subject: "You are hereby invited",
  text: "You are hereby invited to my awesome party!",
  html: "You are hereby invited to my <em>awesome</em> party!",
  path: 'acmecorp.partyapp.invitations'
})
```

### SMS

To send SMS messages, `POST` to `/api/hermes/v1/test/messages/sms`.

### Backend behavior
Upon receiving a post, Hermes writes a `post.hermes_message` to Grove tagged `queued`, and returns 201.
Asynchronously, a daemon picks up created `post.hermes_message`s, tags it with `inprogress` and routes the message to its correct provider. Upon receiving a callback from the provider, the `post.hermes_message` is tagged with either `delivered` or `failed` depending on provider result. Other tags such as `bounced` or `dropped` might also appear, check out any specific provider implementation for details.

If the client included a sensible value in the `batch_label` parameter when posting a message, this parameter will be written to `post.hermes_message.document.batch_label` and can thus be used for keeping track of the send status on a collection of messages. The `batch_label` field is not unique or prefixed in any way, so the client is advised to come up with suitably narrow label.

## Testing and staging

You probably don't want to send actual SMS or email messages in environments that is not production.

You may disable sending by specifying this environment in the realm's config by setting the key:

```
deny_actual_sending_from_environments:
  - staging
```

For any environment except "production", you may view messages sent by Hermes from the API endpoint `/api/hermes/v1/[realm]/messages/latest`.

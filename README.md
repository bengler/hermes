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

## Sending messages

With the example above, it's possible to send SMS and email for the `test` realm. We may then post messages with the API, via `POST` requests:

* To send email, `POST` to `/api/hermes/v1/test/messages/email`.
* To send SMS messages, `POST` to `/api/hermes/v1/test/messages/sms`.

## Testing and staging

You probably don't want to send actual SMS or email messages in environments that is not production.

You may disable sending by specifying this environment in the realm's config by setting the key:

```
deny_actual_sending_from_environments:
  - staging
```

For any environment except "production", you may view messages sent by Hermes from the API endpoint `/api/hermes/v1/[realm]/messages/latest`.

Hermes
======

Hermes is the god of external message delivery.

It can be configured to send whatever - with various providers.

Messages are stored as restricted Grove posts, only available for a god session on that realm.

## Configuration

Before one can send a message, a realm must be configured against a message interface provider.

You configure realms by putting a yml file under ./config/realms.

### Example realm config

Let's configure the realm 'test'.

Create the file ./config/realms/test.yml with the content:

  ```
  session: hermesapplicationfb8f11fjeiwjoefijwe40e82efa7d3895954b4537317689a0960e35c67076
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

The file name is the realm name (with .yml).

The ``session` key is a god session for this realm in Checkpoint.

Under ``implementations`` we put the configuration for various provider implmentations (see [providers.md](providers.md) for details).

### Sending sms and email

With the example above we have set up the possibility to send sms and email for the 'test' realm.

We may then POST messages with the API:

``/api/hermes/v1/test/messages/email`` and ``/api/hermes/v1/test/messages/sms``

The last part of the URL maps directly to the key in the config under ``implementations``

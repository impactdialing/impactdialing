# SSL Setup

[Last updated: Wed April 9 2014]

Customer <_cloudflare_cert_> Heroku <_self-signed_cert_> CloudFlare

We use a self-signed cert to encrypt traffic between the heroku apps and
cloudflare service.

While it is possible to avoid all cert management of http hosts by using
the heroku provided app end-points
(e.g. impactkungfupushupsclient.herokuapp.com) this caused problems
in the past where slurries of 502 errors were returned by Heroku.

In face of the 502 problems, Heroku recommended using the SSL endpoint
directly as it provides us "our own ELB". Whether this still holds is
worth looking into as using the default herokuapp.com domain will simplify ops.

## Changes

### Heartbleed

Update account credentials:

- Mandrill
- AWS
- Heroku
- CloudFlare
- Twilio
- Intuit
- Close.io
- Pivotal
- FreshDesk
- Gmail

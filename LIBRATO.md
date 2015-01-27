## Setup

Main account is owned by `invoices@impactdialing.com`.

New collaborators should be added to the main account and optionally the mail group.

All shared API keys should be added to the main account.

## Updating main account

### Email

If the email of the main account changes:

- the `LIBRATO_USER` environment variable must be updated on all deployments to continue receiving metrics
- any heroku drains are re-keyed on the new email so make sure to add new drains & remove old (http://support.metrics.librato.com/knowledgebase/articles/265391-heroku-native-and-custom-metrics-without-the-libra)
  - Jeremiah has scripts for getting drain URLs from librato

`heroku config:set LIBRATO_USER=invoices@impactdialing.com -a $app`

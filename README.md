## Impact Dialing

### Installing

Install MySQL.

Make sure to disable `STRICT_TRANS_TABLES` sql_mode for MySQL. Locate & update `my.cnf` w/ following.

```
sql_mode=NO_ENGINE_SUBSTITUTION #,STRICT_TRANS_TABLES
```

Restart MySQL.

Install Redis.

Install rvm and proper ruby version (see /.ruby-version).

### Running Specs

Start Redis: `redis-server`.

`rake spec`

### Running Dev Server

Start web & worker processes: `foreman start`.

### Whitelabeling

1. Update `en.yml` (use previous whitelabel entries as template)
  1. Billing Link is only for certain customers
1. Add logo to `public/img` folder, naming file `domain-name-h1.ext`
1. Update CSS in `public/styles/style.css` (use previous whitelabel entries as template - *class names are dynamically generated in erb*)
1. Verify logo displays nicely on localhost
  1. Update `/etc/hosts`
1. Buy domain from badger.com (use visa xx8669)
1. Setup domain in Cloudflare
  1. Use other domains as template
  1. Verify security rules whitelist upload urls
  1. Verify High Security Profile is used
  1. Verify CDN + High Performance is used
  1. Update DNS w/ Badger
1. Add domain to heroku

### Contributing

Master is mainline development and should always be ready to deploy.

Work on features, bugs, etc should be done on topical branches. When ready push branch up and open a pull request.

Once the pull request is merged, delete the branch and carry on.
## Impact Dialing

[![Code Climate](https://codeclimate.com/repos/521ce4f7c7f3a323041654cc/badges/94d7e824870b5f23e781/gpa.png)](https://codeclimate.com/repos/521ce4f7c7f3a323041654cc/feed)

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

### Deployment

Jeremiah: `do you keep parity between aws and heroku at all times?`

Nikhil: `i generally do 3 deploys to prod. 2 heroku and 1 aws`

Deploy to EC2: `bundle exec cap (aws|aws_staging) deploy`

Deploy to Heroku: `heroku push remote-repo branch`

### Servers & Environments

#### Staging

##### EC2

ssh user: `root`

deploy user: `impactdialing`

- Redis-Staging
- Haproxy-Impact
- App1 Stage

##### Heroku

- impactdialing-staging
  - web
      - 1 unicorn
  - workers
      - 1 call\_flow
      - 1 upload\_download
- status-impactdialing
  - web
      - 1 unicorn

#### Production

##### EC2

ssh user: `ubuntu`

deploy user: `impactdialing`

- Redis-production
- Haproxy Prod
- LTS1
- LTS2

##### Heroku

- impactkungfupushupsclient
  - web
      - 2 unicorn
  - workers
      - 1 background\_worker
      - 2 call\_flow
      - 1 clock
      - 1 dialer\_loop
      - 1 dialer\_worker
      - 1 persist\_worker
      - 1 simulator\_loop
      - 1 simulator\_worker
      - 1 twilio\_stats
      - 1 upload\_download

- impactcallergiraffeblue
  - web
    - 2 unicorn

### Whitelabeling

1. Logo should look good at 300x57 and be png
  1. Use imagemagick to convert format if needed `convert img.jpg img.png`
  1. Use imagemagick to resize if needed `convert img.png -resize xx% img-h1.png`
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
1. Add domain to heroku production app

#### Test in staging

1. Add domain to heroku staging app
1. Add the following to `/etc/hosts`
  1. `impactdialing-staging.herokuapp.com whitelabel-domain.com`
1. Visit `whitelabel-domain.com`

### Contributing

Master is mainline development and should always be ready to deploy.

Work on features, bugs, etc should be done on topical branches. When ready push branch up and open a pull request.

Once the pull request is merged, delete the branch and carry on.

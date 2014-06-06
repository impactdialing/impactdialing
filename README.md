## Impact Dialing Server

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

A `.env` file is used to store local environment variables which are required to configure the app environment. So it is necessary to prepend `foreman run` to any test runs. Otherwise the `.env` file will not be loaded.

`foreman run rake spec:note2e` - Run all specs that do not depend on javascript.
`foreman run rake spec:e2e:all` - Run all specs that do depend on javascript.
`foreman run rake spec:e2e:{js,admin,caller}` - Run specs tagged with the same name.

### Running Dev Server

Start web & worker processes: `foreman start`.

### Deployment

Deploy to EC2: `bundle exec cap (aws|aws_staging) deploy`

Deploy to Heroku: `heroku push remote-repo branch`

### Servers & Environments

#### Staging

##### EC2

ssh user: `root`

deploy user: `impactdialing`

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

### Test Phone Numbers

Hello no thank you: 971-264-5495

Minute conversation: 971-264-2814

Reject: 971-264-5346

Busy: 971-264-5467

Repeat adnauseum: 657-888-9655

### Trouble

#### Background Jobs

##### Unique jobs fail to run (resque-loner)

There may be a stale redis key still in memory.

Check:
```
Resque::Plugins::Loner::Helpers.loner_queued?(:queue_name, {class: 'ClassOfPertinentJob', args: []})
```

Then remove it with:
```
Resque::Plugins::Loner::Helpers.mark_loner_as_unqueued(:queue_name, {class: 'ClassOfPertinentJob', args: []})
```

##### Phantom callers

Sometimes caller sessions will remain registered long after the caller has disconnected. There is a job that should clean up these 'Phantom callers' but it currently will fail quietly sporadically.

Clean up phantom sessions by locating the session id at `/admin/state` then open up a rails console and call `end_session` on the 'phantom' CallerSession instance.

# Impact Dialing Client (callveyor)

Tests run on karma, jasmine and grunt. Use `grunt test` to run continuously in Firefox, Safari and Chrome.

Builds are wrapped in a Rake task that handles cleaning files outside the root directory of grunt. Use `rake callveyor:build` to generate a new build of the callveyor app.

See the README in callveyor/ for all of the gory deets.

# Contributing

Master is mainline development and should always be ready to deploy.

Work on features, bugs, etc should be done on topical branches. When ready push branch up and open a pull request.

Once the pull request is merged, delete the branch and carry on.

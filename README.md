# Dependencies

All can be installed through Homebrew.

* Ruby (see `Gemfile` or `.ruby-version` for version)
* Node 0.10.x (for the Angular app in `callveyor`)
* Redis 2.8
* MySQL 5.5.40
* Heroku toolbelt
* Ngrok

# Running in development

Make sure to copy `.env.example` to `.env` and update credentials if needed.

Install gems with `bundle` from the app root. Set up the database with `rake db:create && db:schema:load`. Install caller interface deps with `npm install && bower install` from `callveyor`.

Start MySQL server and Redis server.

Launch the web app with `rails s` (for simple testing only). Launch the web app and background processes with `heroku local -f Procfile.dev` (customize `Procfile.dev` to choose which processes to launch) and visit `localhost:5000` for the admin interface, and `localhost:5000/app` for the caller interface.

Launch the caller interface from `callveyor` with `grunt serve` and visit `localhost:9000/app/login`. (Don't worry about assets not loading.) After logging in, you'll get the error `Cannot GET /app`. Remove `app` from the URL to visit `localhost:9000/` to reach the logged-in caller interface.

Receive Twilio callbacks through Ngrok by running `ngrok http -subdomain=impactdialing 5000`.

After making changes to Callveyor, build the Angular app into the Rails app with `rake callveyor:build`.

# Testing

Run `rspec spec` for Ruby tests.

Run `foreman run rspec features` for acceptance tests.

Run `grunt test` from `callveyor` to continuously run Callveyor tests in Firefox, Safari and Chrome.

# Configuration

- `CALLIN_PHONE`: The Twilio phone number associated with the "Production call-in" TwiML app
- `CALL_END_CALLBACK_HOST`: DEPRECATED
- `CAMPAIGN_EXPIRY`: A number of days; campaigns that have not made any dials in this number of days will be auto-archived
- `DATABASE_READ_SLAVE1_URL`: URL to a MySQL read slave
- `DATABASE_READ_SLAVE2_URL`: URL to a second MySQL read slave
- `DATABASE_SIMULATOR_SLAVE_URL`: URL to a third MySQL read slave, intended for use by predictive simulator workers
- `DATABASE_URL`: URL to MySQL master
- `DO_NOT_CALL_PORTED_LISTS_PROVIDER_URL`: HTTP AUTH URL to tcpacompliance ported lists
- `DO_NOT_CALL_REDIS_URL`: URL to redis instance where block and ported cell lists are cached
- `DO_NOT_CALL_WIRELESS_BLOCK_LIST_PROVIDER_URL`: HTTP AUTH URL to qscdl block lists
- `ENABLE_WORKER_AUTOSCALING`: DEPRECATED
- `HEROKU_APP`: DEPRECATED
- `HEROKU_AUTOSCALE_OAUTH_TOKEN`: DEPRECATED
- `HEROKU_PASS`: DEPRECATED
- `HEROKU_USER`: DEPRECATED
- `HIREFIRE_TOKEN`: Auth token provided by HireFire for auto-scaling
- `INCOMING_CALLBACK_HOST`: HOST of end-points to process TwiML
- `INSTRUMENT_ACTIONS`: Toggle librato-rails experimental `instrument_action` usage; 0 = do not instrument controller actions; 1 = instrument controller actions
- `LIBRATO_SOURCE`: Names the source of the Librato metrics being collected
- `LIBRATO_TOKEN`: Auth token provided by Librato
- `LIBRATO_USER`: Username for Librato account (invoices@impactdialing.com)
- `MANDRILL_API_KEY`: ...
- `MAX_THREADS`: How many threads should puma start (1 - app not proven thread-safe yet)
- `NEW_RELIC_APP_NAME`: DEPRECATED
- `NEW_RELIC_LICENSE_KEY`: DEPRECATED
- `PREDICTIVE_ON_HOLD_THRESHOLD`: Number of seconds a caller can be on-hold on a predictive campaign that hasn't dialed in the last 60 seconds.
- `PUSHER_APP_ID`: ...
- `PUSHER_KEY`: ...
- `PUSHER_SECRET`: ...
- `RACK_ENV`: ...
- `RACK_TIMEOUT`: Number of seconds before rack considers request timed out (max 30 for heroku)
- `RAILS_ENV`: ...
- `RECORDING_ENV`: Root-level folder to store recordings in on s3
- `REDIS_PHONE_KEY_INDEX_STOP`: CAUTION! Changing this requires migrating household data in redis, should be negative four (-4); this determines the position phone numbers are partitioned when creating redis keys and redis hash keys.
- `REDIS_URL`: URL of primary (default) redis instance to connect
- `S3_ACCESS_KEY`: ...
- `S3_BUCKET`: ...
- `S3_SECRET_ACCESS_KEY`: ...
- `SCHEDULER_URL`: DEPRECATED ??
- `STRIPE_PUBLISHABLE_KEY`: ...
- `STRIPE_SECRET_KEY`: ...
- `TWILIO_ACCOUNT`: ...
- `TWILIO_APP_SID`: ...
- `TWILIO_AUTH`: ...
- `TWILIO_CALLBACK_HOST`: HOST of end-points to process TwiML (replacing `INCOMING_CALLBACK_HOST`)
- `TWILIO_CALLBACK_PORT`: Port of that `TWILIO_CALLBACK_HOST` end-points will process TwiML on
- `TWILIO_CAPABILITY_TOKEN_TTL`: TTL of Twilio Client capability tokens (caller app & admin dashboard)
- `TWILIO_FAILOVER_HOST`: HOST of failover end-points to continue or abort processing TwiML
- `TWILIO_MONITOR_APP_SID`: Twilio app id for admin dashboard call monitoring / break-in
- `TWILIO_RETRIES`: Number of retries Twilio ruby client should perform before considering API request as failed
- `UNICORN_TIMEOUT`: DEPRECATED
- `UNICORN_WORKERS`: DEPRECATED (replaced by `WEB_CONCURRENCY`)
- `UPSERT_GEM_ON`: Upsert is a SLOWER & MORE ERROR-PRONE alternative to activerecord-import; 0 = use activerecord-import; 1 = use upsert
- `VOIP_API_URL`: Twilio's API host (api.twilio.com)
- `VOTER_BATCH_SIZE`: Number of rows of CSV data to process before committing to redis during uploads. Keep at a max of 100 down to a min of 20 or 30. Lower value will increase overall upload time but decrease commit time thereby improving redis throughput.
- `WEB_CONCURRENCY`: Number of puma workers to start.

# Whitelabeling

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

## Test in staging

1. Add domain to heroku staging app
1. Add the following to `/etc/hosts`
  1. `impactdialing-staging.herokuapp.com whitelabel-domain.com`
1. Visit `whitelabel-domain.com`

# Test Phone Numbers

Hello no thank you: 971-264-5495

Minute conversation: 971-264-2814

Reject: 971-264-5346

Busy: 971-264-5467

Repeat adnauseum: 657-888-9655

# Trouble

## Phantom callers

Sometimes caller sessions will remain registered long after the caller has disconnected. There is a job that should clean up these 'Phantom callers' but it currently will fail quietly sporadically.

Clean up phantom sessions by locating the session id at `/admin/state` then open up a rails console and call `end_session` on the 'phantom' CallerSession instance.

# Heads up

## Resque

The `resque-loner` gem is used for a few jobs. This gem defines `.redis_key` and uses that to track job uniqueness. Careful not to override this in implementation classes.

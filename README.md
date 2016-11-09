# Dependencies

All can be installed through Homebrew.

* Ruby (see `Gemfile` or `.ruby-version` for version)
* Node 0.10.x (for the Angular app in `callveyor`)
* Redis 2.8
* MySQL 5.5.40
* Heroku toolbelt
* Ngrok

# Configuring Twilio

Create a separate Twilio account for dev/staging and production - it will be
much easier to track down errors in development. Use the ngrok.io subdomain as the
host for development, and the herokuapp.com host for production.

Create [TwiML apps](https://www.twilio.com/console/voice/dev-tools/twiml-apps):

* Browser phone: request and fallback to `/twiml/caller_sessions`, status callback to `/caller/end_session`
* Dial in: request and fallback to `/callin/create`, status callback to `/caller/end_session`
* Dashboard: request and fallback to `/client/monitors/callers/start`

Set TWILIO_APP_SID to the browser phone app's SID.

Set TWILIO_MONITOR_APP_SID to the dashboard app's SID.

For each call-in number, configure the number to use the dial in app.

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

# Deploying to production

We run Impact Dialing on Heroku. We deploy to two apps.
The main one ("impactdialing") serves admin.impactdialing.com and caller.impactdialing.
The other one ("impactdialing-twiml") is solely responsible for handling Twilio webhooks,
and runs a single Perforance dyno.

Performance dynos run on a dedicated VM and don't suffer from performance
leakage from neighboring dynos, and so have a consistently fast response time
that we couldn't achieve on standard dynos.
By isolating the two apps, we can be sure that slow requests on the main app don't disrupt call flow,
which is very latency-sensitive.

The main impactdialing app should be configured to have the Cloudflare proxy
enabled, to protect from attacks.
impactdialing-twiml should not have the Cloudflare proxy enabled, as it only
services requests from Twilio, and we want those requests to stay within the AWS
datacenter and not take a roundtrip through Cloudflare first.
Make sure to keep this URL a secret, since it does not have Cloudflare protection.

# Services

## Running the damn thing

* Heroku - hosting/platform
* HireFire - autoscaling Heroku
* Cloudflare - DNS, etc
* RDS - MySQL hosting
* S3 - list and audio storage, daily Redis backups, log backups
* RedisLabs - Redis hosting
* Pusher - realtime
* Twilio - calls
* Mandrill - emails

## Troubleshooting

* Bugsnag - exceptions
* Papertrail - logs
* Librato - dashboards
* PagerDuty - alerts

## Testing

* Blazemeter - load testing
* Sauce - browser testing
* CircleCI - continuous integration
* Ngrok - tunnel from a public domain to localhost

## Support

* Freshdesk - email support
* Olark - chat support
* Usersnap - screenshots/JS dump support

# Configuration

- `CALLIN_PHONE`: The Twilio phone number associated with the "Production call-in" TwiML app
- `CAMPAIGN_EXPIRY`: A number of days; campaigns that have not made any dials in this number of days will be auto-archived
- `DATABASE_READ_SLAVE1_URL`: URL to a MySQL read slave
- `DATABASE_READ_SLAVE2_URL`: URL to a second MySQL read slave
- `DATABASE_SIMULATOR_SLAVE_URL`: URL to a third MySQL read slave, intended for use by predictive simulator workers
- `DATABASE_URL`: URL to MySQL master
- `DO_NOT_CALL_PORTED_LISTS_PROVIDER_URL`: HTTP AUTH URL to tcpacompliance ported lists
- `DO_NOT_CALL_REDIS_URL`: URL to redis instance where block and ported cell lists are cached
- `DO_NOT_CALL_WIRELESS_BLOCK_LIST_PROVIDER_URL`: HTTP AUTH URL to qscdl block lists
- `HIREFIRE_TOKEN`: Auth token provided by HireFire for auto-scaling
- `INCOMING_CALLBACK_HOST`: HOST of end-points to process TwiML
- `INSTRUMENT_ACTIONS`: Toggle librato-rails experimental `instrument_action` usage; 0 = do not instrument controller actions; 1 = instrument controller actions
- `LIBRATO_SOURCE`: Names the source of the Librato metrics being collected
- `LIBRATO_TOKEN`: Auth token provided by Librato
- `LIBRATO_USER`: Username for Librato account (invoices@impactdialing.com)
- `MANDRILL_API_KEY`: ...
- `MAX_THREADS`: How many threads should puma start (1 - app not proven thread-safe yet)
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
- `STRIPE_PUBLISHABLE_KEY`: ...
- `STRIPE_SECRET_KEY`: ...
- `TWILIO_ACCOUNT`: ...
- `TWILIO_APP_SID`:  SID of the Browser Phone TwiML app
- `TWILIO_AUTH`: ...
- `TWILIO_CALLBACK_HOST`: the hostname of the impactdialing-twiml Heroku app
- `TWILIO_CALLBACK_PORT`: the port of the impactdialing-twiml Heroku app
- `TWILIO_CAPABILITY_TOKEN_TTL`: TTL of Twilio Client capability tokens (caller app & admin dashboard)
- `TWILIO_FAILOVER_HOST`: the same as the hostname of the impactdialing-twiml Heroku app
- `TWILIO_MONITOR_APP_SID`: SID of the Dashboard TwiML app
- `TWILIO_RETRIES`: Number of retries Twilio ruby client should perform before considering API request as failed
- `UPSERT_GEM_ON`: Upsert is a SLOWER & MORE ERROR-PRONE alternative to activerecord-import; 0 = use activerecord-import; 1 = use upsert
- `VOIP_API_URL`: Twilio's API host (api.twilio.com)
- `VOTER_BATCH_SIZE`: Number of rows of CSV data to process before committing to redis during uploads. Keep at a max of 100 down to a min of 20 or 30. Lower value will increase overall upload time but decrease commit time thereby improving redis throughput.
- `WEB_CONCURRENCY`: Number of puma workers to start.

# Queue names and their job classes

* billing -> Billing::Jobs::AutoRecharge, Billing::Jobs::StripeEvent, DebitJob
* call_flow -> CallerPusherJob, CampaignOutOfNumbersJob, Providers::Phones::Jobs::DropMessage, EndRunningCallJob, RedirectCallerJob, VoterConnectedPusherJob
* dial_queue -> CallFlow::DialQueue::Jobs::Recycle, CallFlow::Web::Jobs::CacheContactFields, DoNotCall::Jobs::BlockedNumberCreatedOrDestroyed, CachePhonesOnlyScriptQuestions, CallerGroupJob
* dialer_worker -> CalculateDialsJob, DialerJob
* general -> Archival::Jobs::CampaignArchived, Archival::Jobs::CampaignSweeper, DoNotCall::Jobs::CachePortedLists, DoNotCall::Jobs::CacheWirelessBlockList, DoNotCall::Jobs::RefreshPortedLists, DoNotCall::Jobs::RefreshWirelessBlockList, DeliverInvitationEmailJob, PhantomCallerJob, ResetVoterListCounterCache
* import -> CallList::Jobs::Import, CallList::Jobs::Prune, CallList::Jobs::ToggleActive, CallList::Jobs::Upload
* persist_jobs -> none!
* persistence -> CallFlow::Jobs::Persistence
* reports -> AdminReportJob, ReportAccountUsageJob, ReportDownloadJob
* simulator_worker -> SimulatorJob
* twilio_stats -> UpdateStatsAttemptsEm, UpdateStatsTransfersEm, UpdateTwilioStatsCallerSession

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

# Heads up

## Resque

The `resque-loner` gem is used for a few jobs. This gem defines `.redis_key` and uses that to track job uniqueness. Careful not to override this in implementation classes.

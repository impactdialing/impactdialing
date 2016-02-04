## Impact Dialing Server

### Setting up for development

### Running Specs

A `.env` file is used to store local environment variables which are required to configure the app environment. So it is necessary to prepend `foreman run` to any test runs. Otherwise the `.env` file will not be loaded.

`foreman run rspec spec/` - Run all unit/integration specs.
`foreman run rspec features/` - Run all acceptance specs.

### Running Dev Server

Start web & worker processes: `foreman start`.

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

##### Phantom callers

Sometimes caller sessions will remain registered long after the caller has disconnected. There is a job that should clean up these 'Phantom callers' but it currently will fail quietly sporadically.

Clean up phantom sessions by locating the session id at `/admin/state` then open up a rails console and call `end_session` on the 'phantom' CallerSession instance.

# Impact Dialing Client (callveyor)

Tests run on karma, jasmine and grunt. Use `grunt test` to run continuously in Firefox, Safari and Chrome.

Builds are wrapped in a Rake task that handles cleaning files outside the root directory of grunt. Use `rake callveyor:build` to generate a new build of the callveyor app.

See the README in callveyor/ for all of the gory deets.

# Contributing

Master is mainline development and should always be ready to deploy.

Work on features, bugs, etc should be done on topical branches IN YOUR OWN FORK. When ready push branch up and open a pull request.

Once the pull request is merged, delete the branch and carry on.

## Abandon Rate Spec

Legally, abandon rate must be calculated as (number abandoned / (number abandoned + number connected to voter)).

# Heads up

## Resque

The `resque-loner` gem is used for a few jobs. This gem defines `.redis_key` and uses that to track job uniqueness. Careful not to override this in implementation classes.

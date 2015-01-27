# Service provider dependencies

    - Impact Dialing web apps
      |- CloudFlare
      |- AWS EC2, RDS (MySQL), Route55
        |- heroku
        |- redislabs
        |- twilio
        |- pusher
        |- usersnap

## Twilio

https://www.twilio.com/docs/availability-reliability

### Server failover

Fallback URLs can be configured via TwiML app configurations or specified as a parameter to some request sent to Twilio. All end-points that serve TwiML during synchronous requests are candidates for this configuration.

The Fallback host should be configured per environment:
- impactdialing-monitor.herokuapp.com (Production)
- impactdialing-staging.herokuapp.com (Staging)

The monitor app performs monitoring via a loop and scheduled jobs on background dynos. To act as failover it will also have a 1x web dyno. This dyno must be prevented from sleeping so that it is immediately available to process requests in the event of a failover. To this end, an additional job should be added to the monitor queue that pings the web dyno and records the response via Librato. Librato should be configured to alert if the web dyno is not responsive w/in 5 seconds.

Synchronous Callee-facing TwiML end-points:
- /calls/:call_id/incoming (response to dial requests made from TwilioLib)
- /calls/:call_id/disconnected (specified by action attribute of Conference TwiML served at /incoming)

Synchronous PhonesOnlyCaller-facing TwiML end-points
- /callin/create (Voice URL on Twilio phone number)
- /identify_caller (specified by Caller#ask_for_pin, called from /callin/create)
- /caller/:id/read_instruction_options (specified by action attribute of Gather TwiML served at /identify_caller, called by PhonesOnlyCallerSession#callin_choice)
- /caller/:id/callin_choice (specified by Redirect in CallerTwiml#instructions_options_twiml)
- /caller/:id/ready_to_call (specified by CallerTwiml#ready_to_call_twiml)
- /caller/:id/next_call
- /caller/:id/conference_started_phones_only_preview
- /caller/:id/conference_started_phones_only_power
- /caller/:id/conference_started_phones_only_predictive
- /caller/:id/gather_response
- /calls/:id/disconnected
- /transfer/callee?params_required
- /transfer/caller?params_required
- /transfer/:id/connect?params_required
- /transfer/:id/disconnect?params_required

Synchronous WebCaller-facing TwiML end-points
- /callin/create (Voice URL on Twilio phone number)
- /identify_caller (specified by Caller#ask_for_pin, called from /callin/create)
- /caller/start_calling (Voice URL on Twilio TwiML app)
- /caller/:caller_id/pause
- /caller/:caller_id/continue_conf
- /calls/:id/disconnected
- /transfer/callee?params_required
- /transfer/caller?params_required
- /transfer/:id/connect?params_required
- /transfer/:id/disconnect?params_required

Asynchronous administrative Twilio end-points; fallbacks here would be nice but won't impact call flow
- /caller/end_session
- /calls/:call_id/call_ended
- /transfer/:id/end?params_required
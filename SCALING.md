Scaling

To Michael:
Storage-wise on MySQL we are fine - 280GB free but connections might be a problem. We maintain about 70 pretty consistently right now and max will be about 300. I'll scale up some dynos tonight to see what we require at X scale of dynos - I imagine we'll need larger db for enough connections to support 1,000 callers though maybe not. I think our current scale can support about 40-50 callers reliably before certain dynos need to be scaled.

I'd estimate about an hour downtime to move to a larger RDS instance.

What kind of notice will VAN give us before they jump? Do we have any indication of how likely they are to move to us? They'll be exercising our caller app & admin site directly, right?

If VAN does jump to us, do we expect they'll want to upload all their lists ASAP? Did they hint as to how they envision the migration going down?

Scaling up in # certain dynos e.g. background workers that run a majority of UniqueJob won't have much effect since processing is skipped if UniqueJob instance is already queued/being processed; i.e. scaling # dynos to support more TwilioStats collections or DebitJobs will have no effect on the speed data is processed/persisted. Scaling up in the size of these dynos will be useful, as it would mean faster processing of each job - a PX dyno would insulate us from resource contention.

To take advantage of scaling # dynos for these jobs, they need tweaked so they operate on individual records or even a specific set of records, rather than a dynamic set determined on each run. These jobs do not directly affect call flow operations so lack of ability to add workers won't affect callers but under high load, we will allow a higher than usual number of minutes to be used than should if/when these queues will back up.

## Overview

As number of callers increases web traffic will increase on:
- impactkungfupushupsclient
- impactcallergiraffeblue
- impactdialing-twiml

And the number of jobs will increase for these queues:
- dialer_worker predictive (resque: twilio)
- call_flow all (sidekiq: much twilio & all pusher)

These may help with dialer performance under load:
- dialer_loop predictive (resque: queues DialerJobs on dialer_worker queue, then sleeps for 3 seconds)

Most other jobs run on a schedule and handle long-term data persistence, reports, emails, etc.

20-30 callers are witnessed as reliably handled in production with at ~127 req/min peak for TwiML:
- 2 2x browser-facing dynos and web concurrency of 4 (unicorn workers)
- all background jobs scaled to 1 1x dyno
- 1 PX Twilio-facing dyno and web concurrency of 25 (unicorn workers)

## Measurements

In ideal conditions (on low-latency dev env [MBP SSD 8GB, served via ngrok proxy to localhost, local redis & mysql])

4 HTTP requests are generated for every busy dial attempt:
	- 1 by the browser (/call_voter)
	- 3 by Twilio (/call_end?status=busy; /pause; /continue_conf)

7 HTTP requests are generated for every answered dial attempt (regardless if answered by human):
	- 2 by the browser (/call_voter; /submit_result)
	- 5 by Twilio (/incoming; /disconnected; /call_end?status=complete; /pause; /continue_conf)

Busy dial attempts take approximately 5 seconds from dial to dial on Power.

Answered dial attempts take approximately 3 seconds to connect when answered immediately, 1 second to transition to wrap-up and 2 seconds to transition from wrap-up to dialing the next voter. Assuming a 60 second conversation, and 30 seconds to perform wrap-up steps, total time per answered call ~96 seconds.

### TwiML

Best case Preview/Power dial rate when all attempts are busy: 12 /minute /caller (36 TwiML requests & 12 Browser)
Best case Preview/Power dial rate when all attempts are answered w/ 1 minute conversation: 0.50 /minute /caller (~3 TwiML requests & 2 Browser)

20 callers: 60-720 req /min

1,000 callers: 3,000-36,000 req /min

### Browser

20 callers: 40-240 req /min

1,000 callers: 2,000 - 12,000 req /min

## Observations from manually

### 150 - 180 callers

impactdialing-ps
- dialer_worker: 3
- simulator_worker: 2
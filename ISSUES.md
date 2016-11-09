# Wrong presented counts

Sometimes the ringing and presented counts get off from their true values.
Usually, the presented count will be positive, and the ringing count will be negative.
Often, but not always, they will have the same absolute value.

There is logic to automatically fix this in Campaign#ringing_count and
Campaign#presented_count, as well as PredictiveDialRate#unfixed_campaigns.
Scheduling `rake dial_queue:inflight_stats:reset` to run every evening will also
clean up any campaigns that get off during the day so they have a clean slate
the next day.

But the presented count still sometimes gets stuck at a positive value and has
to be fixed by hand on `/admin/state`

The PredictiveDialRate monitor will let you know if the problem is causing no
dials to go out of a campaign, but will not alert you to a campaign slowed down
but not completely stopped.

One possible cause of this problem is a common exception we get,
`Resque::DirtyExit, resque#dialer_worker`. However, I have seen this problem when
that exception had not occurred recently.

# Predictive dialing stopped

Sometimes the predictive dialer will simply stop dialing for no apparent reason,
often for just one or two campaigns while others continue to work.
Restarting the app fixes the problem. One hypothesis is that it has something
to do with Resque Loner, and while implementing a TTL on the loner lock has
fixed most of the problems, this still pops up from time to time.

# Stuck callers

Sometimes a caller will be waiting on hold, and yet a call will be abandoned
instead of being connected to the caller. When this happens, it is logged by
the ImproperAbandons monitor to help you track down the cause of the bug.

# Gray screen of death

Sometimes a caller clicks "Save & continue", and then their screen gets stuck
there. Usersnap reports including a JavaScript console dump show no JS errors.
One hypothesis is that occasionally jobs with Pusher events are getting dropped.

# Double dials

In Preview and Power modes, occasionally the same number will be dialed twice
in quick succession. The RecycleRateViolations monitor will create an alert
if this happens to help debug.

# Twilio warnings

No matter how high our servers' availability is and despite colocating with
Twilio in AWS US East, Twilio will always report 502s from callbacks
from time to time, but we don't see these requests in our logs.
Twilio's unofficial response on this issue is:

"These happen, we're not sure why. We haven't been able to track them down to find root cause and have spent a not insignificant time with AWS trying to sort it out. From the perspective of our proxies it's a timeout on requests and we get nothing back from your server. We have a backlog of items to improve the webhook pipeline to make it resilient to these types of failures, introduce configurable timeouts and retries. Unfortunately the pipeline works well enough so it's constantly been pushed back in favor of higher priority work. I'm going to keep trying to get it done because these drove me crazy when I worked with customers but I can't put a timeframe on it."

Twilio also occasionally can't connect to our servers, and our servers
occasionally return 500s due to Redis connection errors or some such problem.

Twilio fallbackUrls are configured to retry the request at the same URL to
deal with these issues. Unfortunately, Twilio statusCallbackUrls cannot be
configured with a fallback URL, and are not retried. So if a call is not
answered and the status callback fails, the dialer will believe the call
is still ringing, forever.

I have [Alert Triggers](https://www.twilio.com/console/dev-tools/triggers/alert)
set up on "Any Warning" at values 1-30, with a webhook to Zapier that triggers
a PagerDuty alarm. When I get the alarm, I go the [Twilio debugger](https://www.twilio.com/console/dev-tools/debugger?quickDate=24&showErrors=false),
click the warning, click the Resource SID, and click the Replay arrow.

I've automated this process with [twilio-nightmare](https://github.com/impactdialing/twilio-nightmare),
but was too nervous to try it out mid-election season, and never finished
persisting the retried requests or figuring out deployment.

Twilio recently released a Debugger Webhook Developer Preview that could be
useful for automatically retrying requests, but it doesn't include the request
parameters for warnings. They say:

"That information isn't being published into the Debugging system yet. That's true across the board (Debugger, webhook and REST API). The Voice team is aware of this and is working on publishing this information."

# Persistence problems

Sometimes there is a mismatch between the call data UUID and the dialed
household UUID, and the exception
`undefined method id for nil:NilClass, app/models/concerns/call_flow/persistence/survey_responses.rb:31` or
`undefined method [] for nil:NilClass, app/models/concerns/call_flow/persistence/leads.rb:204`
is raised.
This can be "fixed" automatically by scheduling
`rake persistence_workaround:fix_lead_mismatch`
to be run every few minutes, but if there are multiple voters in the household,
it blindly assigns the call to the first household member.

Other times, the Twilio `queued` status isn't updated to the proper status, yielding

`Mysql2::Error: Column 'status' cannot be null, app/models/concerns/call_flow/persistence/call.rb:15`

This can be manually fixed like this:

```
irb(main):001:0> call_sid = "CA02f884c5290e0b2dddf86db32efe82d8"
irb(main):006:0> call = CallFlow::Call::Dialed.new(TWILIO_ACCOUNT, call_sid)
=> #<CallFlow::Call::Dialed:0x007f64a9fd9ae8 @account_sid="ACe3044770ed77c1e613f92ea5f9eb82bf", @sid="CA52cc1adbf60d491dde537a853e332212">
irb(main):007:0> call.storage
=> #<CallFlow::Call::Storage:0x007f64a9fd6f28 @group_key="ACe3044770ed77c1e613f92ea5f9eb82bf", @object_key="CA52cc1adbf60d491dde537a853e332212", @namespace="dialed">
irb(main):008:0> call.storage.attributes
=> {"phone"=>"3057516906", "direction"=>"outbound-api", "sid"=>"CA52cc1adbf60d491dde537a853e332212", "to"=>"+13057516906", "account_sid"=>"ACe3044770ed77c1e613f92ea5f9eb82bf", "duration"=>"0", "status"=>"queued", "campaign_id"=>"5972", "from"=>"+13057517283", "campaign_type"=>"Predictive"}
# check Twilio for the correct status; eg https://www.twilio.com/user/account/log/calls?sid=CA52cc1adbf60d491dde537a853e332212
irb(main):009:0> call.storage[:status] = 'busy'
=> "busy"
irb(main):010:0> call.storage.attributes
=> {"phone"=>"3057516906", "direction"=>"outbound-api", "sid"=>"CA52cc1adbf60d491dde537a853e332212", "to"=>"+13057516906", "account_sid"=>"ACe3044770ed77c1e613f92ea5f9eb82bf", "duration"=>"0", "status"=>"busy", "campaign_id"=>"5972", "from"=>"+13057517283", "campaign_type"=>"Predictive"}
```

But obviously a root-cause solution would be better.

We also much less commonly get `ActiveRecord::RecordNotUnique` from
`app/models/concerns/call_flow/persistence/call.rb:6`.

# Phantom callers

Note: this section is very old and I have no idea if it is still accurate.

Sometimes caller sessions will remain registered long after the caller has disconnected. There is a job that should clean up these 'Phantom callers' but it currently will fail quietly sporadically.

Clean up phantom sessions by locating the session id at `/admin/state` then open up a rails console and call `end_session` on the 'phantom' CallerSession instance.

# Redis connection pooling

We commonly get Redis::CannotConnectErrors. Using connection pooling should
greatly reduce the occurrence of these.

# Server-side exceptions

Besides the exceptions listed above, these are the most common server-side
exceptions we get:

* CallFlow::DialQueue::EmptyHousehold, app/models/concerns/call_flow/dial_queue.rb:84 (this is harmless but should be fixed)
* undefined method storage for nil:NilClass, app/models/phones_only_caller_session.rb:97
* undefined method response for #<Providers::Phone::Twilio::Response:0x007fe9cefb9a40>, app/models/concerns/providers/phone/jobs/drop_message.rb:47
* ActionDispatch::Cookies::CookieOverflow, client#index
* ActiveRecord::StatementInvalid, client/scripts#update and client/scripts#create (fix is to convert mysql to utf8mb4_bin from utf8 because mysql does not support full utf8 charset)
* Stripe::CardError, Your card was declined., app/models/billing/payment_gateway.rb:49 (just need to catch and surface to user)

All other server-side exceptions are pretty rare.

# Client-side exceptions

All are in order from most to least common.
The exceptions are the most common by far:

* dialer.ready: Twilio Error. [undefined] A connection is currently active
* CallerUndefined/app: CallStationCache had no caller (appears to be harmless)
* dialer.ready: Unable to get property 'insertBefore' of undefined or null reference

These are much less common:

* dialer.ready: Cannot read property 'session_key' of undefined
* dialer.active: Client timeout reached. Message drop queued successfully. Completion message not received.
* Survey fields failed to load
* Can't find variable: cause
* dialer.hold: uncaught exception: Twilio.Exception: 31204: Cannot register. Token not validated

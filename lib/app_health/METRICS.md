# TODO

- determine uniform source & name scheme
-- goals:
--- minimize admin overhead w/out sacrificing granularity
---- eg setup a single 'redis persistence failure' alert to trigger on
---- any job failing to run
--- minimize dev overhead w/out sacrificing capture consistency or granularity over time
--- 

# App metrics

## Auto-scaling

### Background Workers

1. *Churn* Frequent requests to modify number of background workers can slow things down by increasing runtime duration of jobs while each performs scaling request in after perform hooks.
  - `autoscale.processname.total`
  - `autoscale.processname.error`
  - `autoscale.processname.up`
  - `autoscale.processname.down`
1. *Jobs* Spikes/valleys in the number of certain jobs run can indicate systemic or user-induced issues.
  - `processname.jobs`
  - `processname.jobname.jobs`

## Call performance metrics (RFC)

### Source template

`host.account_id.campaign_id.caller_session_id.campaign_type.caller_session_type.caller_phone_type`

Librato provides 2 layers of naming metrics: a source and the name of the metric itself. Metric names should be abstract and generally applicable. Source can be specific to hosts, accounts, users, etc and Librato UI will allow us to filter to various scopes on the source name. So the source template above used on a metric e.g. `dialer.contact.answered` would allow us to inspect `dialer.contact.answered` metrics specific to a particular account, caller session, campaign type, etc but also to zoom out and see system-wide `dialer.contact.answered` metrics.

### Request, callback/webhook latency

1. *Callers online* Provide a yardstick to determine how other indicators are affected by number of callers and how many callers are at a given state at some point in time.
  - `dialer.caller_sessions.on_call`
  - `dialer.caller_sessions.hold`
  - `dialer.caller_sessions.wrap_up`
1. *Number of dial requests made:Number of TwiML requests served* Maintaining a minimal ratio of transitions in call state to TwiML served will reduce load; i.e. redirecting a caller should (ideally) result in 1 request for TwiML.
  - `dialer.requests.total`
  - `dialer.requests.error`
  - `dialer.requests.completed`
  - `dialer.responses.completed`
  - `dialer.responses.error`
1. *Call flow latency* Get insight to latency between initiating a request to Twilio and serving TwiML.
  - `dialer.contact.answered`
  - `dialer.contact.busy`
  - `dialer.contact.error`
  - `dialer.transfer.answered`
  - `dialer.transfer.busy`
  - `dialer.transfer.error`
  - `dialer.contact.redirect`
  - `dialer.transfer.redirect`
  - `dialer.caller.redirect`

    When we initiate a request to Twilio, start a timer e.g. RedisTimer.start(unique_identifiers)
    When proper TwiML or an error is served to Twilio, stop timer and submit metric sample# e.g. sample#dialer.contact.answered=RedisTimer.stop(unique_identifiers)

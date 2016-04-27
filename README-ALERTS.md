## Librato Alerts

There are a few alerts configured through Librato so when metrics change, Librato will alert and trigger PagerDuty.

https://metrics.librato.com/alerts#/index

## PagerDuty Alerts

The rest of the alerts are triggered through the monitor app (impactdialing-monitor on heroku).

- AppHealth::Monitor::PredictiveDialRate
- AppHealth::Monitor::RecycleRateViolations

### PredictiveDialRate

This currently suffers quite a few false positives. Usually the false positives happen when only a few predictive callers are online and they've been on the phone for over a minute. It does catch problems and when there is a problem (ie the campaign hasn't dialed recently and it should have) then a few things could be the cause.

1. `CalculateDialsJob` is stuck: see https://github.com/impactdialing/Impact-Dialing/wiki/Stuck-Resque-Unique-Jobs
1. Ringing count (or possibly presented count) are off: see https://github.com/impactdialing/Impact-Dialing/wiki/Inflight-Stats

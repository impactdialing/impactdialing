## Sidekiq workers / work queues

https://github.com/mperham/sidekiq/wiki/Monitoring

### How big are sidekiq queues

```
require 'sidekiq/api'
Sidekiq::Queue.new.size
```

### How long are sidekiq jobs spending in the queues

```
require 'sidekiq/api'
Sidekiq::Queue.new.latency
```

### Are we queueing multiple jobs w/ identical payloads

Add some client-side middleware to track this data.

```
class Mine::IdenticalPayloadMonitor
  def call(worker, payload, queue)
    # incr payload counter
    key = "sidekiq_payload_monitor:#{payload.keys.zip(payload.values).map{|t| t.join(':')}.join(':')}"
    redis.increment key
    redis.expire key, 86400
  end
end
```

### Is there a bug in sidekiq or redis causing multiple workers to pick up the same job

```
```

## Recycle Rate

### Approach 1

Monitor our data. Count call attempts with a created_at time in the last hour grouped by voter_id. Given recent events (Twilio API errors) our data is probably more reliable from an availability/freshness perspective.

```
-- alert query, run often to check for problem
select count(*) from call_attempts where created_at >= NOW() - INTERVAL 2 MINUTE group by voter_id having count(*) > 1

-- report query, run once problem is identified
select count(*),voter_id,GROUP_CONCAT(dialer_mode) dial_mode,GROUP_CONCAT(campaign_id) campaigns,GROUP_CONCAT(status) statuses,GROUP_CONCAT(created_at) time,NOW() cur_time,GROUP_CONCAT(tDuration) seconds,GROUP_CONCAT(sid) SIDs from call_attempts where created_at >= NOW() - INTERVAL 2 MINUTE group by voter_id,campaign_id having count(*) > 1
```

### Approach 2

Monitor Twilio data. Pull call data from Twilio periodically to store call counts per phone number in redis to minimize api calls. Send counts to librato every update.

### Combo

Put both approaches in place and tweak alarms such that librato consults each figure for better accuracy. Also improves troubleshooting time for things like Twilio REST timeouts eg when we redirect callers.

## Abandon Rate

```
campaign_id=4487
campaign = Campaign.find(campaign_id)
campaign.abandon_rate_acceptable?

answered_dials = campaign.call_attempts.between(Time.at(1334561385) , Time.now).with_status([CallAttempt::Status::SUCCESS, CallAttempt::Status::SCHEDULED]).size
abandon_count  = campaign.call_attempts.between(Time.at(1334561385) , Time.now).with_status(CallAttempt::Status::ABANDONED).size
abandon_rate   = abandon_count.to_f/(answered_dials <= 0 ? 1 : answered_dials)
abandon_rate  <= campaign.acceptable_abandon_rate
```

## Which VoterLists are Enabled

```
campaign_id=4414
campaign = Campaign.find(campaign_id)
print campaign.voter_lists.map{|l| [l.id, l.name, l.enabled, l.voters.where(enabled: !l.enabled).count, l.updated_at].join(', ')}.join("\n")
```

## Were calls made to voters on disabled lists after the lists updated_at date

```
campaign_id=4414
campaign = Campaign.find(campaign_id)
out = []
campaign.voter_lists.where(enabled: false).map do |l|
  r = []
  r << l.id
  r << l.name
  r << l.enabled
  r << l.updated_at
  r << l.voters.where('last_call_attempt_time >= ?', l.updated_at).count
  r << l.voters.where('last_call_attempt_time >= ?', l.updated_at).map(&:last_call_attempt_time).join('; ')
  out << r.join(', ')
end
print "List ID, List Name, List Enabled, # Voters called since list updated, Call times since last list update"
print out.join("\n")
```

## Which Voters have no first or last name

```
campaign_id=4487
campaign = Campaign.find(campaign_id)
campaign.voter_lists.map{|l| }
```

## Why are there delays in the caller UI when saving and hanging up

These tickets are all complaints of 2 callers having to wait too long after clicking Hangup or Save and Continue.

```
campaign_id = 4470
tickets = {
  '467' => {
    time: '29/10/2014 20:08:00 -07:00:00',
    caller_id: 31259,
    caller_session_id: 1495152,
    voter_id: 185772223,
    phone: '4158217132'
  },
  '468' => {
    time: '29/10/2014 20:09:00 -07:00:00',
    caller_id: 31258,
    caller_session_id: 1495017,
    voter_id: 185772247,
    phone: '4152825143'
  },
  '469' => {
    time: '29/10/2014 20:09:00 -07:00:00',
    caller_id: 31258,
    caller_session_id: 1495017,
    voter_id: 185772247,
    phone: '4152825143'
  },
  '470' => {
    time: '29/10/2014 20:12:00 -07:00:00',
    caller_id: 31258,
    caller_session_id: 1495017,
    voter_id: 185772278,
    phone: '4152527309'
  }
}
```

### What response times did these callers see from the caller app

#### What are the relevant Call IDs

```
voter_ids = []
tickets.each{|t| voter_ids << t.last[:voter_id]}
data = CallAttempt.where(voter_id: voter_ids).map{|ca| {voter_id: ca.voter_id, call_id: ca.call_id, sid: ca.sid}}
call_ids = data.map{|d| d[:call_id]} # => [63460731, 63460757, 63460794]
search_q = "(submit OR hangup) AND (#{call_ids.join(' OR ')})" # => (submit OR hangup) AND (63460731 OR 63460757 OR 63460794)
```

Response times log

```
Oct 29 20:09:04 at=info method=POST path="/call_center/api/63460757/submit_result" host=caller.impactdialing.com request_id=9083a097-0743-4189-b0b2-6cde63c49aa8 fwd="2604:5500:20:4d6:ad09:56cd:a81e:d8cf, 199.27.133.65" dyno=web.3 connect=11ms service=157ms status=200 bytes=564 
Oct 29 20:09:04 app/web.3:  method=POST path=/call_center/api/63460757/submit_result format=html controller=calls action=submit_result status=200 duration=34.97 view=0.30 db=11.15 
Oct 29 20:11:40 at=info method=POST path="/call_center/api/63460794/hangup" host=caller.impactdialing.com request_id=cfc3a190-c33e-4c6f-ac11-f297adaad12a fwd="2604:5500:20:4d6:ad09:56cd:a81e:d8cf, 199.27.128.205" dyno=web.1 connect=1ms service=21ms status=200 bytes=552 
Oct 29 20:11:40 app/web.1:  method=POST path=/call_center/api/63460794/hangup format=html controller=calls action=hangup status=200 duration=11.98 view=0.54 db=4.73 
Oct 29 20:11:54 at=info method=POST path="/call_center/api/63460794/submit_result" host=caller.impactdialing.com request_id=533a3cec-9b18-49d9-a00e-4bd2ff41b9a3 fwd="2604:5500:20:4d6:ad09:56cd:a81e:d8cf, 199.27.133.65" dyno=web.2 connect=2ms service=36ms status=200 bytes=564 
Oct 29 20:11:55 app/web.2:  method=POST path=/call_center/api/63460794/submit_result format=html controller=calls action=submit_result status=200 duration=25.72 view=0.43 db=2.51 
Oct 29 20:13:14 app/web.3:  method=POST path=/call_center/api/63460757/hangup format=html controller=calls action=hangup status=200 duration=11.55 view=0.42 db=4.06 
Oct 29 20:13:14 at=info method=POST path="/call_center/api/63460757/hangup" host=caller.impactdialing.com request_id=5ca0189b-7a32-4786-ade0-00e02c7ff22b fwd="2604:5500:20:4d6:ad09:56cd:a81e:d8cf, 199.27.133.141" dyno=web.3 connect=2ms service=21ms status=200 bytes=552
```

### How did this last voter list get on my campaign?

```
campaign_id = 4541
campaign = Campaign.find(campaign_id)
campaign.voter_lists.last.created_at
# => Tue, 04 Nov 2014 23:32:56 UTC
# seek to ^^ in papertrail
# papertrail search
method=POST voter_lists
# grab IP addresses
# update papertrail search for IPs
# get an idea of what that user did
```

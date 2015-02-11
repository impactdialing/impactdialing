# Jan 2015

## Features

### General Admin

- list upload dropdown menus now auto-select matching entries
- improved ui consistency (alternating table row bg colors on campaign edit page)
- simplified campaign list area a bit (less clutter, faster load times)

### General Dialer

- implement twilio fallback url for `/incoming` end-point
  - if there's an error when a call is answered then the call is marked as abaonded
- householding support (recycle rate applies per phone number)
  - households are per-campaign but span voter lists; ie it is possible to have members of the same household uploaded from different lists so long as those lists are uploaded to the same campaign
  - cell phones are no longer removed from uploaded lists when 'scrub cell' checkbox checked. if members of a household are in 2 different lists then the cell scrub option is looked up for the last uploaded list; ie if cells are scrubbed for first list but not for 2nd list and each list contains members of the same household, then after the 2nd list is uploaded (cells not scrubbed) any cell phones that exist in both lists will be dialed, even if they were scrubbed for the 1st list.
  - move dial queue to redis
- campaign may report out of numbers erroneously in limited situations; we handle this by verifying the campaign is out of numbers in the background, which can take a few minutes for large lists but will allow callers to try again after a short break to see if the campaign is really out of numbers.

### Preview Dialer

- skipped voters (really households now) are no longer marked as 'skipped', they will keep whatever the last call status was and be rotated back into the queue once the recycle rate expires; eg if my household status is 'Busy' and i skip that household, they will keep the status of 'Busy' - previously, this status would be reset to 'not called' or 'skipped' which both overwrote the actual status & (in case of skipped) did not say anything of the last /call/ status.

### Phones only

- First available voter is auto-selected for callers when a call is answered (webui callers must select the voter when submitting answers)
  - if this fails for any reason we try assigning the voter again when processing submitted answer data (see Answer data section)

## Housekeeping

- improve automated test coverage (help catch bugs faster)

## Answer data

- stop throwing out answer data

## Bug fixes

- make dashboard stats more reliable & up-to-date (# ringing, etc)
- stop quietly losing answer data 
  - AnswerJob & PersistPhonesOnlyAnswers both swallow exceptions but do not protect against data loss once removed from redis.
- stop immediately disconnecting incoming calls when we have tmp error updating caller session
  (retry a few times first, then disconnect)
- voters that were about to be dialed before the caller(s) logged off in preview/power/predictive modes will no longer be stuck in 'dialed but not really' limbo, they are treated as 'skipped' voters

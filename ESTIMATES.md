## Householding (as of 4 Dec 2014)
  households table et al - 
    - port tests/validations/methods/queries/db indices etc - 3 day
    - port last call caches, list uploads, queue caching (household/voter data) - 2 day
    - port blocked number jobs to update households instead of voters - 1 day
    - migrate data from Voters to Households - 1 day
    - port call status persist jobs (PersistCalls, AnsweredJob, etc) - 2 day
    - auto-select first caller - 1 day
  qa - 1 day

  present caller with all not-completed household members for selection - 2 days
    - update pusher jobs to send multiple voters
    - update callveyor contact module to process & list multiple voters
    - update callveyor survey module to collect voter_id from list
  qa - 1 day
  

## todo (as of 12 Dec 2014)
[x] - finish planning update to PersistCalls
[-] - add job to process presented numbers that have not been removed after recycle rate expiry
  - happy path: presented numbers are removed via DialQueue#dialed at /call_end
  - unhappy path: twilio req to /call_end fails & numbers stick in presented limbo
  - this job is to cover the unhappy path
[x] - finish updating FakeCallData to mimic PersistCalls
[-] - catch up most specs
[-] - update phones only caller session:
  - move voter_in_progress-as-a-dial-target behavior to redis
[-] - finish spec catch-up
[-] - move Available#zpoppush retries out to job queue layer
[m] - update preview.skip for household (phones only & web)
[m] - schedule ProcessRecycleBin
[mt] - update caller app to list voters / handle new data format from pusher
  - ? go back and revert current pusher method sending data
  - ? add newly named event/pusher method to send new data (maintain support for old caller apps)
[t] - update caller app voter list to have radio buttons & have selection sent w/ survey
  - auto-select first voter before submit if none selected -- do not select option before submit is triggered; busy calls should be associated w/ household, not voter
[t] - update dial queue/households to handle completed voters (ie remove them)
[mm] - update reports
  - download
  - dials
[tt] - verify other reports
[tt] - verify dashboard stats
[tt] - verify calling
  - all campaign types
  - phones only, web only (desktop), phone + web (desktop & mobile)

## todo (as of 15 Dec 2014)
[x] - voter list change job
[x] - blocked number created/destroyed
[x] - make a dial on power campaign

## todo (as of 16 Dec 2014)
[x] - integration test Power (auto-selecting first presentable voter)
  [x] - Answer data
  [x] - Call data
[x] - /submit & /submit_and_stop accept voter_id
[x] - wrapped-up call list stores voter_id
[x] - persistence layer updates CallAttempt#voter_id from wrapped-up call list
[x] - add job to process presented numbers that have not been removed after recycle rate expiry
  - happy path: presented numbers are removed via DialQueue#dialed at /call_end
  - unhappy path: twilio req to /call_end fails & numbers stick in presented limbo
  - this job is to cover the unhappy path
[x] - update phones only caller session:
  - move voter_in_progress-as-a-dial-target behavior to twiml
[x] - update preview.skip for household (phones only & web)
[x] - update caller app survey to send voter_id param
[x] - finish spec catch-up
[x] - update predictive to work off dial queue
[x] - update /incoming endpoint for householding +predictive,power,preview+
[x] - update dial queue/households to handle completed voters (ie remove them)
[x] - verify dashboard stats

[x] - update reports
  [x] - answers appear to not be persisting
    - AnsweredJob & PersistPhonesOnlyAnswers swallow exceptions causing data loss when data just pulled from redis is not pushed back
    - CallAttempt#wrapup_now depends on Caller#is_phones_only? but sometimes the caller isn't there eg when an application error occurs during a twilio request for twiml ie /disconnect.
  [x] - download
  [x] - dials
    [x] - summary: fix available/not available counts; household may not be unavailable when status == SUCCESS
[x] - campaign & caller usage reports
[x] - schedule ProcessRecycleBin
[x] - verify other reports
[x] - verify calling
  - all campaign types
  - phones only, web only (desktop), phone + web (desktop & mobile)
[=] - handle potential race condition in dial queue
  [x] - persist calls queues process presented voters
  [!] - issue is, process presented voters only runs if calls are made; if only dials left to make are those stale & presented then process presented voters won't run since calls aren't being made because everyone is stale & presented
    [-] - solution: queue process presented voters to run every minute
    [] - make a note that this race condition exists and could cause problems in unlikely event that an hour worth of PersistCalls did not touch presented numbers when it should have
      [] - change PersistCalls.process_presented_voters -> process_recycle_bin & rely on above implementation for process presented voters only
  [X:)] - nice thing is, process presented voters also processes recycled voters; so the race condition of processing recycle households before persisting relevant data (ie if a persistence takes >1hr to complete) is handled by this approach
  - if recycled households are processed for re-use before relevant call data has been persisted, then these households could be erroneously added to the available dial queue, since correct silo'ing depends on data from mysql. eg if a household is dialed and the last voter dispositioned but PersistCalls takes 62 minutes to update relevant mysql records and recycle bin is processed 61 minutes after the call, then the household will be made available for dialing.
  - this is more likely to occur when refreshing dial queue after campaign out of numbers
  [**] - protect 1: update Processing jobs to take ids or phone numbers from updated records in PersistCalls & only process those items through the recycle bin
  [:(] - protect 2: add configurable pad to max score of recycled members; update configured pad (eg 10 minutes) if # of items in any lists that PersistCalls use as input grow for X consecutive minutes and/or reach Y threshold
[x] - move Available#zpoppush retries out to job queue layer
[mt] - update caller app to list voters / handle new data format from pusher
  - ? go back and revert current pusher method sending data
  - ? add newly named event/pusher method to send new data (maintain support for old caller apps)
[t] - update caller app voter list to have radio buttons & have selection sent w/ survey
  - auto-select first voter before submit if none selected -- do not select option before submit is triggered; busy calls should be associated w/ household, not voter

# bugs

[x] - phones only answers don't update voters `call_back` attribute => retry options on possible responses have no effect
[x] - phones only answers are thrown away completely if any error occurs during processing

done Monday
- improve cache lifecycle management (clean-up after removing last voter)
- finish fixes from Sat & get tests passing

done Tuesday
- code review, clean-up, refactor, add tests for better coverage
- improve & test race condition handling when popping next numbers off queue

todo as of Jan 14

[x] - ProcessPresentedVoters
  - Voter or Household #skip should decrement Preview#presented_count
    - WebUI
    - PhonesOnly
[x] - determine best queue (existing or new) & framework (sidekiq or resque) for cache jobs
[x] - update cache jobs as needed for best queue & framework
[x] - schedule/setup entry points for jobs

Jan 15

[x] - clean-up RedisPhonesOnlyAnswers.keys[:pending] 

Jan 16

[x] - bug: download reports per lead does not include 'not dialed'
[x] - bug: when script 'selected fields' change, the cache is not updated & so the data may be incomplete
  [x] - object to manage Script#voter_fields in redis hash where Script#id is key & #voter_fields is value
  [x] - update Voter#cache_data to return all Voter#fields & Voter#custom_fields
  [x] - utility to filter hashes based on whitelist of keys
  [x] - utility to build hash of "#{attr}_flag" => true
  [x] - CallFlow::Web::Json.build(contact_fields.data, households.find(phone)[:voters]) to pull next number & format Voter#fields for transmit (lookup selected fields in Script cache & pull needed data from Households)
  [x] - job to manage cache lifecycle of Script#voter_fields
  [x] - notification to queue job on scripts.updated (keep things de-coupled)

Jan 19
[x] - verify uploads w/ CustomID work as expected
  [note] - this works as expected. potential issue when changing phone number & only 1 voter exists in household. eg ListA creates HouseholdA & VoterA; ListB updates VoterA phone so a new Household (B) is created. HouseholdA still exists but has no voters. This could make reports confusing (HouseholdA will always show as not reached).
    [possible solution] - present users w/ an option to clean-up their lists by deleting Households that have never been dialed and have no voters associated.
[] - update caller app to list voters / handle new data format from pusher
  - ? go back and revert current pusher method sending data
  - ? add newly named event/pusher method to send new data (maintain support for old caller apps)
[] - update caller app voter list to have radio buttons & have selection sent w/ survey
  - auto-select first voter before submit if none selected -- do not select option before submit is triggered; busy calls should be associated w/ household, not voter
[] - plan migrate campaign, list & call data
[] - migrate data
[] - qa
  - preview, power, predictive
  - phones only, webui
  - warm, cold transfers (webui, power, predictive)
  - answering machine detect, use recordings, auto message drops
  - use recordings, manual message drops
  - call back or don't after leaving messages
[] - bug: predictive usage report shows -1 for on hold, should be ~3

## Householding (as of 4 Dec 2014)
  households table et al - 
    - port tests/validations/methods/queries/db indices etc - 3 day
    - port last call caches, list uploads, queue caching (household/voter data) - 2 day
    - port blocked number jobs to update households instead of voters - 1 day
    - port call status persist jobs (PersistCalls, AnsweredJob, etc) - 2 day
    - auto-select first caller - 1 day
  qa - 1 day

  present caller with all not-completed household members for selection - 2 days
    - update pusher jobs to send multiple voters
    - update callveyor contact module to process & list multiple voters
    - update callveyor survey module to collect voter_id from list
  qa - 1 day
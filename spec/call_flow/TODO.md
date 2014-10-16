TODO:
- periodically process Dialed set & remove completed numbers (all voters have completed) or add incomplete numbers back to Available
- integrate seeding to voter list change jobs
- make sure voter list change job is re-queued when VoterList not found (ie after initial creation)
- integration test / verify design & implementation & performance w/ large lists

- finalize optimal key expirations for each main structure & related meta-data
- plan & add clean monitoring metrics to track per account/campaign

Other Considers
- cache blocked numbers (by itself might be useful in reducing sql queries => speeding up voter load queries even for report pages)
  - downsides: increased memory usage
- might be worth isolating this set of caches from the 'Production' redis db & spinning up a dedicated instance to caching call list data
- don't remove numbers from active set until complete, instead update scores when dialed, use Dialed set as 'RecycleBin' and just subtract the union of RecycleBin & BlockedNumbers from the active set, then return the first from reduced active set
  - downsides: increased memory usage to a) maintain cache of blocked numbers; b) duplication of set of blocked numbers in active set & c) duplication of members between RecycleBin & active sets... and d) blocked numbers would need to be stored in sorted set to for compatible ops w/ RecycleBin & active sets, further increasing memory usage.
  - upsides: simplify management of phone numbers, reduce dependence on mysql for call flow (performance boost for callers/callees)

## Must Do

When caller app is updated to support householding then remove entire household when dialed number fails w/ bad request.
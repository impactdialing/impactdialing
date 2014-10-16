## CallFlow doc'd

### Overview

Three sets plus a collection of households formed from ++CallFlow::DialQueue::Available++ ++CallFlow::DialQueue::RecycleBin++ ++CallFlow::DialQueue::DoNotCall++ ++CallFlow::DialQueue::Households++. When combined as ++CallFlow::DialQueue++ they efficiently manage redis cache layer
for call list data of active or recently active campaigns.

### Lifecycle

#### Beginnings

Populate these:
- CallFlow::DialQueue::Available
- CallFlow::DialQueue::Households
- CallFlow::DialQueue::DoNotCall

Whenever they're not already populated and one of these happens:
- voter list is uploaded
- user associated with account or campaign logs in

#### Middles

Update these:
- CallFlow::DialQueue::Available (remove any in DNC)
- CallFlow::DialQueue::Households (remove any in DNC)
- CallFlow::DialQueue::DoNotCall

Whenever new BlockedNumbers are created or imported via console.

#### Endings

Delete these:
- CallFlow::DialQueue::Available
- CallFlow::DialQueue::RecycleBin
- CallFlow::DialQueue::DoNotCall
- CallFlow::DialQueue::Households

When 7 days have passed and no user associated with the account has logged in.

### Lifecycle Management

Is handled by a few different background jobs.

#### CallFlow::Jobs::CacheVoters

Queued from VoterListChangeJob when a list is enabled/disabled or created.

Queued from auth/n flow when user of campaign/account logs in after period of inactivity.

#### CallFlow::Jobs::CacheDNC

Queued from BlockedNumber.after_create callback.

Queued from auth/n flow when user of campaign/account logs in after period of inactivity.

#### CallFlow::Jobs::ProcessRecycleBin

Scheduled job, queued from clock according to time interval. ... Do we have a sidekiq clock?

#### CallFlow::Jobs::ClearUnusedCache

Runs once a day at 4a. Iterates over cached items and removes those associated with accounts that have had no log-ins within the last 7 days.
# API Plan

- Outline request/response cycle
- Outline general limits (req rate, etc)
- Describe end-points, parameters and properties returned
- Outline JS client SDK
- Outline JS client app (ImpactDialer)

## REST End-points

### Requests

#### To Impact Dialing

All requests must include parameters for API authentication:

- api_key
- api_auth

#### From Impact Dialing

We will request designated URLs when needed to POST data (e.g. survey results) back to your servers.

### Responses



### Common properties

- uri
- name
- actions
- resources

### List properties

- next_page
- prev_page
- first_page
- last_page

### Administrative

Coming soon...

### Account

Coming soon...

## API Client SDKs

### Javascript

Available for download as bower package

Coming soon...

## Apps

### Javascript

Available for download as bower package

Coming soon...


# API minimal

## Version 1

Just manage call flow and notify user of changes to state.

Benefits:

- increased flexibility (future-proofing)
- minimal data consistency worries (no sync-hell)

Drawbacks:

- user handles authentication of callers
- user handles back-end wiring

Features:

- make calls
  - [req] type of dialer to use (Preview, Power, Predictive)
  - [req] call state webhook url (call related notifications sent here; ringing, hung-up, etc)
  - [req] phone numbers webhook url (we will GET this resource when ready for more numbers to dial)

### End-points

POST /v1/call

params:

- dialer_type (Preview,Power,Predictive)
- from
- call_state_url (e.g. http://customer.site.com/impact_dialing/calls/:id/callers/:caller_id/state_change)
- phone_numbers_url (e.g. http://customer.site.com/impact_dialing/campaigns/:id/phone_numbers?page=2&limit=100)
- phone_number (e.g. 14445551234 or [14445551234,14445554321,...])

## Version 2

Features:

- upload a list of phone numbers
  - [req] user-defined identifier (e.g. campaign id for campaign obj in user-system)
  - [req] webhook url (upload related notifications will be sent here)

- make calls
  - [opt.1a] phone numbers webhook url (we will GET this resource when ready for more numbers to dial)
  - [opt.1b] uploaded list id (we will dial numbers in the associated list)


# API Requirements

The Impact Dialing API should

- use web standards where they make sense (e.g. REST, HTTP, etc)
- be friendly to the developer and be explorable via a browser address bar
- be simple, intuitive and consistent to make adoption not only easy but pleasant
- provide enough flexibility to power majority of the ImpactDialing UI
- be efficient, while maintaining balance with the other requirements

## Version 1

Should deliver:

- admin REST api
- javascript sdk for caller stuff

### Use cases

#### One

Benefits:

- completely hosted (user just builds the interface)
- export/import required to sync data

Drawbacks:

- complex to implement (completely hosted)
- export/import required to sync data

Administrative

Manage everything.

- manage campaigns, messages, lists, callers, caller groups
- manage blocked numbers
- manage scripts, script texts, questions, notes, possible responses, transfers, custom fields, selected (custom & system) fields

Caller

Do everything.

- manage caller sessions (cookie session)
- get caller script (campaign_calls/show)
- start dialing (manage call sessions)
- pub/sub events
- transfer call
- submit results & continue
- submit results & stop (manage call sessions)

Support webhooks:

- for phone call states
- dashboard events ??

## Version 2

GET Reports ??
... Dashboard
... Account management
... kick callers from conference
... eavesdrop
... break-in
... phones only calls

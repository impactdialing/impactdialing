## Dialer.ready state

Initial app state once a caller has authenticated.

Caller will be able to:
- click 'Start calling' to dial-in via browser
- call displayed call-in number & enter displayed PIN to dial-in via phone

### Transitions

Only the following transitions are permitted. If a prohibited transition is requested (e.g. via WS event) then a `dialer:ready:transition:error` event should be $broadcast with the offending transition data.

Dialer.ready -> Dialer.hold

Dialer.stop  -> Dialer.ready

Dialer.error...?
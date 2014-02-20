## Dialer.ready state

Initial app state once a caller has authenticated.

Caller will be able to:
- click 'Start calling' to dial-in via browser
- call displayed call-in number & enter displayed PIN to dial-in via phone

### Transitions

`Dialer.ready -> Dialer.hold`

Requirements for above transition success:

- pusher is loaded & connected
- twilio is loaded & ready

`Dialer.stop -> Dialer.ready`

Requirements for above transition success:

- caller is connected
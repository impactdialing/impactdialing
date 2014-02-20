## Dialer.stop state

Entered when user clicks 'Stop calling'.

### Transitions

`dialer.hold -> dialer.stop`

It won't be possible for a user to 'Stop calling' unless they are in the hold state. This will prevent accidental clicks from disconnecting the user from an active call.
## On-call (aka 'active')

The active state is reached when the called party answers and is connected to the caller.

The only visible change should be an update to the dialer status message.

### Transitions

`dialer.hold -> dialer.active`

`dialer.active -> dialer.wrap`
## Wrap-up

The wrap-up (aka 'wrap') state is reached when the called party has disconnected and the caller is in the process of submitting their survey responses.

Should be visible:

- contact info
- Save & continue / Save & stop buttons

Should be disabled:

- Dialer buttons (Stop calling, Dial, Skip, etc)

### Transitions

`dialer.active -> dialer.wrap`

`dialer.wrap -> dialer.hold`

`dialer.wrap -> dialer.stop`

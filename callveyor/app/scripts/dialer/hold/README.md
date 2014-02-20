## onHold State

### WebSocket Based Transitions

`dialer.ready > dialer.hold`

The following are the WS events that may trigger this transition:

- *Predictive:* `caller_connected_dialer`
- *Preview & Power:* `caller_connected`

`dialer.hold > dialer.dialing`

The following WS events may trigger this transition:

- *Predictive:* N/A (dialing & onHold are synonymous in Predictive campaigns)
- *Preview & Power:* `calling_voter`

`dialer.hold > dialer.onCall`

WS events that may trigger this transition:

- *Predictive:* `voter_connected_dialer`
- *Preview & Power:* `voter_connected`
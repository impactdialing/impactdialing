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

### contactInfo view

Handles display of contact info.

Contact info will be displayed in these states:

- Preview, Power & Predictive
  - onCall
  - wrapUp

- Power, Preview
  - hold/dialing

Contact info will be loaded primarily via WS events:

- Preview, Power, Predictive
  - caller_reassigned

- Predictive
  - voter_connected_dialer

- Preview, Power
  - conference_started

Contact info will also be loaded via Preview#skip but how best to emit this data, via WS or synchronous http request?
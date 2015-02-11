# Dial queue test scenarios

## Ordering

Dial mode  |Several passes without pause|Several passes with pauses
-----------|----------------------------|--------------------------
|Preview   |X                           |X            
|Power     |X                           |X
|Predictive|X                           |X

### Dial modes

In all dial modes, when a dial attempt is answered then the call is handled according to Campaign settings. Regardless of Campaign settings, when a dial is answered by a human, they have a 95%-100% chance of being connected to a caller. In Preview/Power modes, this chance is closer to 99%-100% since dials are made only when a caller is available. Predictive mode provides a feature that increases the chance of a caller not being available to handle an answered dial.

#### Preview

Pull a voter from the dial queue, associate with a caller and then present the voter to a caller before dialing. Provide the caller the options to skip or dial the voter.

#### Power

Pull a voter from the dial queue, associate with a caller and then present the voter to a caller and dial the voter automatically. Caller has no options to skip or dial the voter.

#### Predictive

Pull 1 or more voters from the dial queue up to the number of possible dials that can be made at once. 

Dial all of the voters pulled from the queue right away.

The first answered dial will be connected to the caller who has been on hold (waiting to handle an answered call) the longest. Subsequent answered dials are handled simularly. When there are no callers on hold (available to take an answered dial) then the answered dial is hung-up and the attempt recorded as abandoned.

### Scenarios

#### Several passes without pause

Use case: a list is uploaded and caller(s) begin calling and continues until the campaign runs out of numbers.

Voters are dialed in the same order they are uploaded on the first pass.

On subsequent passes, Voters are dialed in the same order as the first pass excluding Voters who were dialed and successfully dispositioned or who's dial attempts failed for technical reasons (unsupported/invalid phone number, network error, etc) or who's previous call attempts have not reached recycle rate expiry.

#### Several passes with pause

Use case: a list is uploaded and caller(s) begin calling but all callers stop for lunch before the campaign runs out of numbers.

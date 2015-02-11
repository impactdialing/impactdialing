# Pusher issues

## Problem #1

Browser does not always receive events. Could be caused by temporary disconnect.

Possible Solution:

Update client code to detect state of pusher connection and respond accordingly.

## Problem #2

Server occasionally fails to send events due to inability to connect to pusher.

Possible Solution:

Retry these connections until confirmation of receipt is received.

This post describes an example of how to confirm receipt of messages:
http://pusher.tenderapp.com/kb/faq-common-requests/what-happens-if-a-user-is-on-a-poor-connection-that-occasionally-drops-will-they-miss-messages
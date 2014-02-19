## Dialer

### States, Events & Transitions

States

- init (page, scripts, data, etc are loading)
- ready (caller is logged-in)
- dialing (start calling was clicked [TwilioJS], Dial was clicked [Preview ONLY] or Transfer was clicked)
- on-hold (caller is connected either via browser or phone and enjoying music)
- on-call (caller is talking to dialed party)
    - on-warm-transfer (caller is talking to 2 dialed parties)
- wrap-up (caller is doing any post-call work and is not available for calls)

Events

- dial error (start calling, Dial btn or Transfer)
- dial success

### Pseudo-code

```
var dialer = angular.module('callveyor.dialer', [
  'TwilioServiceProvider',
  'PusherServiceProvider',
])
```

```
.config([
  'PusherServiceProvider', 'TwilioServiceProvider',
  (PusherServiceProvider, TwilioServiceProvider) ->
    TwilioServiceProvider.setTwilioUrl('//static.twilio.com/libs/twiliojs/1.1/twilio.min.js')
    TwilioServiceProvider.setToken('twilio-token')
    ## goes in provider --
    # Twilio.Device.setup(this.model.get("twilio_token"), {'debug':true});

    PusherServiceProvider.setPusherUrl('//d3dy5gmtp8yhk7.cloudfront.net/2.1/pusher.min.js')
    PusherServiceProvider.setToken('pusher-token')
])
```

```
.controller('DialerCtrl',  ['$scope', 'Pusher', 'Twilio', ( $scope, Pusher, Twilio ) {
    # subscribe to connection events for monitoring
    Pusher.connection.bind('connecting')
    Pusher.connection.bind('connected')
    Pusher.connection.bind('unavailable')
    Pusher.connection.bind('failed')
    Pusher.connection.bind('disconnected')

    # subscribe to call flow events
    Pusher.bind('start_calling')
    Pusher.bind('caller_connected_dialer')
    Pusher.bind('conference_started')
    Pusher.bind('caller_reassigned')
    Pusher.bind('calling_voter')
    Pusher.bind('voter_connected')
    Pusher.bind('voter_connected_dialer')
    Pusher.bind('voter_disconnected')
    Pusher.bind('caller_disconnected')
    Pusher.bind('transfer_busy')
    Pusher.bind('transfer_connected')
    Pusher.bind('transfer_conference_ended')
    Pusher.bind('warm_transfer')
    Pusher.bind('cold_transfer')
    Pusher.bind('caller_kicked_off')

    # When Twilio is ready to connect
    Twilio.Device.ready(->);
    # When Twilio connects
    Twilio.Device.connect(->);
    # When Twilio offline
    Twilio.Device.offline(->);
    # When Twilio disconnects
    Twilio.Device.disconnect(->);
    # When Twilio has an error
    Twilio.Device.error(->);
})
```
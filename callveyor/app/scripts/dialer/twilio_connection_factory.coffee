mod = angular.module('idTwilioConnectionHandlers', [
  'ui.router',
  'idFlash',
  'idTwilio'
])

mod.factory('idTwilioConnectionFactory', [
  '$rootScope', '$state', '$cacheFactory', 'idFlashFactory', 'idTwilioService'
  ($rootScope,   $state,   $cacheFactory,   idFlashFactory,   idTwilioService) ->
    console.log 'idTwilioConnectionFactory'
    _twilioCache = $cacheFactory.get('Twilio') || $cacheFactory('Twilio')
    twilioParams = {}

    factory = {
      connect: (params) ->
        twilioParams = params
        idTwilioService.then(factory.resolved, factory.resolveError)

      connected: (connection) ->
        console.log 'connected', connection
        _twilioCache.put('connection', connection)
        $state.go('dialer.hold')

      # ready: (device) ->
      #   console.log 'twilio connection ready', device

      error: (error) ->
        console.log 'report this problem', error
        idFlashFactory.now('error', 'Browser phone could not connect to the call center. Please dial-in to continue.', 5000)
        $state.go('dialer.ready')

      resolved: (twilio) ->
        console.log 'bindAndConnect', twilio
        twilio.Device.connect(factory.connected)
        # twilio.Device.ready(handlers.ready)
        twilio.Device.error(factory.error)
        twilio.Device.connect(twilioParams)

      resolveError: (err) ->
        console.log 'idTwilioService error', err
        idFlashFactory.now('error', 'Browser phone setup failed. Please dial-in to continue.', 5000)
    }

    factory
])
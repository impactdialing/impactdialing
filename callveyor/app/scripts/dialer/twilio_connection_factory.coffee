mod = angular.module('idTwilioConnectionHandlers', [
  'ui.router',
  'idFlash',
  'idTransition',
  'idTwilio'
])

mod.factory('idTwilioConnectionFactory', [
  '$rootScope', '$state', 'TwilioCache', 'idFlashFactory', 'idTwilioService', 'idTransitionPrevented'
  ($rootScope,   $state,   TwilioCache,   idFlashFactory,   idTwilioService,   idTransitionPrevented) ->
    console.log 'idTwilioConnectionFactory'
    twilioParams = {}

    factory = {
      connect: (params) ->
        twilioParams = params
        idTwilioService.then(factory.resolved, factory.resolveError)

      connected: (connection) ->
        console.log 'connected', connection
        TwilioCache.put('connection', connection)
        p = $state.go('dialer.hold')
        p.catch(idTransitionPrevented)

      # ready: (device) ->
      #   console.log 'twilio connection ready', device

      disconnected: (connection) ->
        console.log 'twilio disconnected', connection

      error: (error) ->
        console.log 'report this problem', error
        idFlashFactory.now('danger', 'Browser phone could not connect to the call center. Please dial-in to continue.')
        p = $state.go('dialer.ready')
        p.catch(idTransitionPrevented)

      resolved: (twilio) ->
        console.log 'idTwilioService resolved', twilio
        twilio.Device.connect(factory.connected)
        # twilio.Device.ready(handlers.ready)
        twilio.Device.disconnect(factory.disconnected)
        twilio.Device.error(factory.error)
        twilio.Device.connect(twilioParams)

      resolveError: (err) ->
        console.log 'idTwilioService error', err
        idFlashFactory.now('danger', 'Browser phone setup failed. Please dial-in to continue.')
    }

    factory
])
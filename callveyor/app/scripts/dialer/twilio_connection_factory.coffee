mod = angular.module('idTwilioConnectionHandlers', [
  'ui.router',
  'idFlash',
  'idTransition',
  'idTwilio',
  'idCacheFactories'
])

mod.factory('idTwilioConnectionFactory', [
  '$rootScope', '$window', 'TwilioCache', 'idFlashFactory', 'idTwilioService',
  ($rootScope,   $window,   TwilioCache,   idFlashFactory,   idTwilioService) ->
    twilioParams = {}

    factory = {
      boundEvents: []

      boundEventsMissing: (eventName) ->
        factory.boundEvents.indexOf(eventName) == -1

      connect: (params) ->
        twilioParams = params
        idTwilioService.then(factory.resolved, factory.resolveError)

      connected: (connection) ->
        # console.log 'connected', connection
        TwilioCache.put('connection', connection)
        if angular.isFunction(factory.afterConnected)
          factory.afterConnected()

      # ready: (device) ->
      #   console.log 'twilio connection ready', device

      disconnected: (connection) ->
        console.log 'twilio disconnected', connection
        pending = TwilioCache.get('disconnect_pending')
        unless pending?
          idFlashFactory.now('danger', 'The browser phone has disconnected unexpectedly. Save any responses (you may need to click Hangup first), report the problem and reload the page.')
        else
          TwilioCache.remove('disconnect_pending')

      error: (error) ->
        console.log 'Twilio Connection Error', error
        idFlashFactory.now('danger', 'Browser phone could not connect to the call center. Please refresh the page or dial-in to continue.')
        $window._errs.push(error)
        if angular.isFunction(factory.afterError)
          factory.afterError()

      resolved: (twilio) ->
        # console.log 'idTwilioService resolved', twilio
        if factory.boundEventsMissing('connect')
          twilio.Device.connect(factory.connected)
          factory.boundEvents.push('connect')
          # twilio.Device.ready(handlers.ready)
        if factory.boundEventsMissing('disconnect')
          twilio.Device.disconnect(factory.disconnected)
          factory.boundEvents.push('disconnect')
        if factory.boundEventsMissing('error')
          twilio.Device.error(factory.error)
          factory.boundEvents.push('error')
        twilio.Device.connect(twilioParams)

      resolveError: (err) ->
        # console.log 'idTwilioService error', err
        idFlashFactory.now('danger', 'Browser phone setup failed. Please dial-in to continue.')
    }

    factory
])
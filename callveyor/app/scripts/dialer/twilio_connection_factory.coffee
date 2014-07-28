mod = angular.module('idTwilioConnectionHandlers', [
  'ui.router',
  'idFlash',
  'idTransition',
  'idTwilio',
  'idCacheFactories'
])

mod.factory('idTwilioConnectionFactory', [
  '$rootScope', '$window', '$http', 'TwilioCache', 'idFlashFactory', 'idTwilioService', 'idTwilioConfig',
  ($rootScope,   $window,   $http,   TwilioCache,   idFlashFactory,   idTwilioService,   idTwilioConfig) ->
    twilioParams = {}

    factory = {
      boundEvents: []

      isOffline: ->
        connection = TwilioCache.get('connection')
        if connection? and connection.status() == 'offline'
          return true
        else
          return false

      disconnectAll: ->
        connection = TwilioCache.get('connection')
        if connection?
          TwilioCache.put('disconnect_pending', true)
          connection.disconnect()

      boundEventsMissing: (eventName) ->
        factory.boundEvents.indexOf(eventName) == -1

      recoverWithNewToken: (error) ->
        if parseInt(error.code) == 31205
          unless factory.isOffline()
            factory.disconnectAll()
          idTwilioConfig.fetchToken()
          return true
        else
          return false

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
          idFlashFactory.now('danger', 'Your browser lost its voice connection. Submit your responses and reload the page.')
        else
          TwilioCache.remove('disconnect_pending')

        TwilioCache.remove('connection')

      error: (error) ->
        console.log 'Twilio Connection Error', error
        unless factory.recoverWithNewToken(error)
          idFlashFactory.now('danger', 'Voice connection failed. Refresh the page or dial-in to continue.')
          err = new Error("Error refreshing Twilio Capability Token. [#{error.code}] #{error.message} (#{error.info})")
          $window._errs.push(err)
        if angular.isFunction(factory.afterError)
          factory.afterError()

        TwilioCache.remove('connection')

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

        unless factory.isOffline()
          factory.disconnectAll()

        twilio.Device.connect(twilioParams)

      resolveError: (err) ->
        # console.log 'idTwilioService error', err
        idFlashFactory.now('danger', 'Voice setup failed. Refresh the page or dial-in to continue.')
    }

    factory
])
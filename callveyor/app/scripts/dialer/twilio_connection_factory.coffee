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

      connect: (params) ->
        twilioParams = params
        idTwilioService.then(factory.resolved, factory.resolveError)

      connected: (connection) ->
        TwilioCache.put('connection', connection)
        if angular.isFunction(factory.afterConnected)
          factory.afterConnected()

      disconnected: (connection) ->
        console.log 'twilio disconnected', connection
        pending = TwilioCache.get('disconnect_pending')
        unless pending?
          idFlashFactory.now('danger', 'Your browser lost its voice connection. Submit your responses and reload the page.')
        else
          TwilioCache.remove('disconnect_pending')

        TwilioCache.remove('connection')

      error: (error) ->
        # ignore expired token errors... (new token is fetched when calling initiated)
        return if parseInt(error.code) == 31205
        err = new Error("Twilio Error. [#{error.code}] #{error.message} (#{error.info})")
        $window._errs.push(err)

      resolved: (twilio) ->
        if factory.boundEventsMissing('connect')
          twilio.Device.connect(factory.connected)
          factory.boundEvents.push('connect')
        if factory.boundEventsMissing('disconnect')
          twilio.Device.disconnect(factory.disconnected)
          factory.boundEvents.push('disconnect')
        if factory.boundEventsMissing('error')
          twilio.Device.error(factory.error)
          factory.boundEvents.push('error')

        tokenFetchSuccess = ->
          twilio.Device.connect(twilioParams)
        tokenFetchFail = (err) ->
          idFlashFactory.now('danger', 'Error establishing voice connection. Please refresh and try again.')

        idTwilioConfig.fetchToken(tokenFetchSuccess, tokenFetchFail)

      resolveError: (err) ->
        idFlashFactory.now('danger', 'Voice setup failed. Refresh the page or dial-in to continue.')
    }

    factory
])
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
        # console.log 'twilio disconnected', connection
        pending = TwilioCache.get('disconnect_pending')
        unless pending?
          idFlashFactory.now('danger', 'Your browser lost its voice connection. Please check your internet connection, submit your responses, and reload the page.')
        else
          TwilioCache.remove('disconnect_pending')

        TwilioCache.remove('connection')

      error: (error) ->
        debugger
        switch error.code
          # 310xx Series: General Errors
          when 31000, 31002
            idFlashFactory.now('warning', 'There was an error connecting to the voice servers. Please check your internet connection, submit your responses if applicable, and refresh your page.', false)
          when 31003
            if /^ICE liveness checks failed/.test(error.message)
              idFlashFactory.now('warning', 'Your connection to the voice servers has degraded, and you may experience poor audio quality. Please check your internet connection.', false)
            else if /^ICE negotiation with Twilio failed/.test(error.message)
              idFlashFactory.now('warning', 'Your connection to the voice servers has been lost. Please check your internet connection, submit your responses if applicable, and refresh the page.', false)
          when 31202
            idFlashFactory.now('danger', 'There was an error. Please refresh the page.', false)
          when 31204
            idFlashFactory.now('danger', 'There was an error. Please refresh the page.', false)
          when 31205 # ignore expired token errors... (new token is fetched when calling initiated)
            break
          when 31208
            idFlashFactory.now('warning', 'You denied access to your computer\'s microphone. Please refresh the page and try again.', false)
          else
            err = new Error("Twilio Error. [#{error.code}] #{error.message} (#{error.info})")
            $window.Bugsnag.notifyException(err)

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

        twilio.Device.connect(twilioParams)

      resolveError: (err) ->
        idFlashFactory.now('danger', 'Voice setup failed. Refresh the page or dial-in to continue.')
    }

    factory
])

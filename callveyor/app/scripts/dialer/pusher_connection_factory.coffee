'use strict'

mod = angular.module('pusherConnectionHandlers', [
  'idFlash',
  'angularSpinner'
])

mod.factory('pusherConnectionHandlerFactory', [
  '$rootScope', '$window', '$timeout', 'usSpinnerService', 'idFlashFactory',
  ($rootScope,   $window,   $timeout,   usSpinnerService,   idFlashFactory) ->
    connectionHandler = {
      success: (pusher) ->
        connected = (wtf) ->
          usSpinnerService.stop('global-spinner')
          pusher.connection.unbind('connected', connected)
          pusher.connection.bind('connected', reConnected)
          $rootScope.$broadcast('pusher:ready')
          idFlashFactory.nowAndDismiss('success', 'Connected!', 3000)

        reConnected = (obj) ->
          usSpinnerService.stop('global-spinner')
          flash = ->
            idFlashFactory.nowAndDismiss('success', 'Re-connected!', 3000, false)
          $timeout(flash, 0)

        connecting = (wtf) ->
          usSpinnerService.stop('global-spinner')
          usSpinnerService.spin('global-spinner')
          flash = ->
            idFlashFactory.now('warning', 'Your browser has lost its connection. Reconnecting...', false)
          $timeout(flash, 0)

        unavailable = (wtf) ->
          flash = ->
            idFlashFactory.now('danger', 'Your browser has lost its connection.', false)
          $timeout(flash, 0)

        connectingIn = (delay) ->
          flash = ->
            idFlashFactory.now('warning', "Your browser could not re-connect. Connecting in #{delay} seconds.", false)
          $timeout(flash, 0)

        failed = (wtf) ->
          $rootScope.$broadcast('pusher:bad_browser')

        pusher.connection.bind('connected', connected)
        pusher.connection.bind('connecting', connecting)
        pusher.connection.bind('unavailable', unavailable)
        pusher.connection.bind('connecting_in', connectingIn)
        pusher.connection.bind('failed', failed)
      # Service did not resolve successfully. Most likely the pusher lib failed to load.
      loadError: (error) ->
        error ||= new Error("Pusher service failed to resolve.")
        $window.Bugsnag.notifyException(error)
        idFlashFactory.now('danger', 'An error occurred loading the page. Please refresh to try again.')
    }

    connectionHandler
])

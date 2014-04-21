'use strict'

callveyor = angular.module('callveyor', [
  'config',
  'ui.bootstrap',
  'ui.router',
  'doowb.angular-pusher',
  'idTwilio',
  'idFlash',
  'angularSpinner',
  'callveyor.dialer'
])

callveyor.config([
  'serviceTokens', 'idTwilioServiceProvider', 'PusherServiceProvider',
  (serviceTokens,   idTwilioServiceProvider,   PusherServiceProvider) ->
    idTwilioServiceProvider.setScriptUrl('//static.twilio.com/libs/twiliojs/1.1/twilio.js')
    PusherServiceProvider.setPusherUrl('//d3dy5gmtp8yhk7.cloudfront.net/2.1/pusher.min.js')
    PusherServiceProvider.setToken(serviceTokens.pusher)
])

callveyor.factory('pusherConnectionHandlerFactory', [
  '$state', 'usSpinnerService', 'idFlashFactory',
  ($state,   usSpinnerService,   idFlashFactory) ->
    console.log 'pusherConnectionHandler'

    pusherError = (wtf) ->
      console.log 'pusherError', wtf
      idFlashFactory.now('error', 'Something went wrong. We have been notified and will begin troubleshooting ASAP.')

    reConnecting = (wtf) ->
      console.log 'temporaryConnectionFailure', wtf
      idFlashFactory.now('warning', 'Your browser has lost its connection. Reconnecting...')

    connectionFailure = (wtf) ->
      console.log 'connectionFailure', wtf
      idFlashFactory.now('warning', 'Your browser could not re-connect.')

    connectingIn = (delay) ->
      console.log 'connectingIn', delay
      idFlashFactory.now('warning', "Your browser could not re-connect. Connecting in #{delay} seconds.")

    browserNotSupported = (wtf) ->
      console.log 'browserNotSupported', wtf
      $state.go('dialer.unsupported_browser')

    connectionHandler = {
      success: (pusher) ->
        connecting = ->
          console.log 'pusher-connecting'
          idFlashFactory.now('notice', 'Establishing real-time connection...')
          pusher.connection.unbind('connecting', connecting)
          pusher.connection.bind('connecting', reConnecting)
          usSpinnerService.spin('global-spinner')

        initialConnectedHandler = (wtf) ->
          console.log 'initialConnectedHandler', wtf
          usSpinnerService.stop('global-spinner')
          pusher.connection.unbind('connected', initialConnectedHandler)
          pusher.connection.bind('connected', runTimeConnectedHandler)
          $state.go('dialer.ready')

        runTimeConnectedHandler = (obj) ->
          console.log 'runTimeConnectedHandler', obj
          usSpinnerService.stop('global-spinner')
          idFlashFactory.now('success', 'Connected!', 4000)

        pusher.connection.bind('connecting_in', connectingIn)
        pusher.connection.bind('connecting', connecting)
        pusher.connection.bind('connected', initialConnectedHandler)
        pusher.connection.bind('failed', browserNotSupported)
        pusher.connection.bind('unavailable', connectionFailure)
        pusher.connection.bind('error', pusherError)
      error: (err) -> pusherError(err)
      notify: (pusher) -> console.log 'pusherConnectionHandler.notify', pusher
    }

    connectionHandler
])

callveyor.controller('AppCtrl', [
  '$rootScope', '$scope', '$state', '$http', '$timeout', 'usSpinnerService',
  'PusherService', 'pusherConnectionHandlerFactory', 'idTwilioService',
  'idFlashFactory'
  ($rootScope,   $scope,   $state,   $http,   $timeout, usSpinnerService,
   PusherService,   pusherConnectionHandlerFactory,   idTwilioService,
   idFlashFactory) ->
    console.log 'MainCtrl', PusherService

    idFlashFactory.scope = $scope
    $scope.flash = idFlashFactory

    transitionInProgress = -> usSpinnerService.spin('global-spinner')
    transitionComplete = -> usSpinnerService.stop('global-spinner')
    $rootScope.$on('$stateChangeStart', transitionInProgress)
    $rootScope.$on('$stateChangeSuccess', transitionComplete)
    $rootScope.$on('$stateChangeError', transitionComplete)

    PusherService.then(pusherConnectionHandlerFactory.success,
                       pusherConnectionHandlerFactory.error,
                       pusherConnectionHandlerFactory.notify)

    # d = -> PusherService.then((pusher) -> pusher.disconnect())
    # r = -> PusherService.then((pusher) -> pusher.connect())
    # $timeout(d, 10000)
    # $timeout(r, 20000)
])

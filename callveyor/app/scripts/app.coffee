'use strict'

callveyor = angular.module('callveyor', [
  'config',
  'ui.bootstrap',
  'ui.router',
  'doowb.angular-pusher',
  'pusherConnectionHandlers',
  'idTwilio',
  'idFlash',
  'angularSpinner',
  'callveyor.dialer'
])

callveyor.constant 'currentYear', (new Date()).getFullYear()

callveyor.config([
  'serviceTokens', 'idTwilioServiceProvider', 'PusherServiceProvider',
  (serviceTokens,   idTwilioServiceProvider,   PusherServiceProvider) ->
    idTwilioServiceProvider.setScriptUrl('//static.twilio.com/libs/twiliojs/1.1/twilio.js')
    PusherServiceProvider.setPusherUrl('//d3dy5gmtp8yhk7.cloudfront.net/2.1/pusher.min.js')
    PusherServiceProvider.setToken(serviceTokens.pusher)
])

callveyor.controller('MetaCtrl', [
  '$scope', 'currentYear',
  ($scope, currentYear) ->
    # todo: de-register the $watch on $scope.meta.currentYear
    $scope.meta ||= {}
    $scope.meta.currentYear = currentYear
])

callveyor.controller('AppCtrl', [
  '$rootScope', '$scope', '$state', '$cacheFactory', 'usSpinnerService', 'PusherService', 'pusherConnectionHandlerFactory', 'idFlashFactory'
  ($rootScope,   $scope,   $state,   $cacheFactory,   usSpinnerService,   PusherService,   pusherConnectionHandlerFactory,   idFlashFactory) ->
    idFlashFactory.scope = $scope
    $scope.flash = idFlashFactory

    transitionStart = -> usSpinnerService.spin('global-spinner')
    transitionComplete = -> usSpinnerService.stop('global-spinner')
    $rootScope.$on('$stateChangeStart', transitionStart)
    $rootScope.$on('$stateChangeSuccess', transitionComplete)
    $rootScope.$on('$stateChangeError', transitionComplete)
    # handle pusher app-specific events
    markPusherReady = -> $state.go('dialer.ready')
    abortAllAndNotifyUser = ->
      # todo: implement
      console.log 'Unsupported browser...'

    $rootScope.$on('pusher:ready', markPusherReady)
    $rootScope.$on('pusher:bad_browser', abortAllAndNotifyUser)

    PusherService.then(pusherConnectionHandlerFactory.success,
                       pusherConnectionHandlerFactory.loadError)
])

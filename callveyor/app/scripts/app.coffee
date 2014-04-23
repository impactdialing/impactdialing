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

callveyor.config([
  'serviceTokens', 'idTwilioServiceProvider', 'PusherServiceProvider',
  (serviceTokens,   idTwilioServiceProvider,   PusherServiceProvider) ->
    idTwilioServiceProvider.setScriptUrl('//static.twilio.com/libs/twiliojs/1.1/twilio.js')
    PusherServiceProvider.setPusherUrl('//d3dy5gmtp8yhk7.cloudfront.net/2.1/pusher.min.js')
    PusherServiceProvider.setToken(serviceTokens.pusher)
])

callveyor.controller('AppCtrl', [
  '$rootScope', '$scope', 'usSpinnerService', 'PusherService', 'pusherConnectionHandlerFactory', 'idFlashFactory'
  ($rootScope,   $scope,   usSpinnerService,   PusherService,   pusherConnectionHandlerFactory,   idFlashFactory) ->
    console.log 'MainCtrl', PusherService

    idFlashFactory.scope = $scope
    $scope.flash = idFlashFactory

    transitionStart = -> usSpinnerService.spin('global-spinner')
    transitionComplete = -> usSpinnerService.stop('global-spinner')
    $rootScope.$on('$stateChangeStart', transitionStart)
    $rootScope.$on('$stateChangeSuccess', transitionComplete)
    $rootScope.$on('$stateChangeError', transitionComplete)

    PusherService.then(pusherConnectionHandlerFactory.success,
                       pusherConnectionHandlerFactory.loadError,
                       pusherConnectionHandlerFactory.notify)
])

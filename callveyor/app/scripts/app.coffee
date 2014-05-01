'use strict'

a = angular.module('idTransition', [
  'angularSpinner'
])
a.factory('idTransitionPrevented', [
  '$rootScope', 'usSpinnerService',
  ($rootScope,   usSpinnerService) ->
    fn = (errObj) ->
      console.log 'report this problem', errObj
      $rootScope.transitionInProgress = false
      usSpinnerService.stop('global-spinner')

    fn
])

callveyor = angular.module('callveyor', [
  'config',
  'ui.bootstrap',
  'ui.router',
  'doowb.angular-pusher',
  'pusherConnectionHandlers',
  'idTwilio',
  'idFlash',
  'idTransition',
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
  '$rootScope', '$scope', '$state', '$cacheFactory', 'usSpinnerService', 'PusherService', 'pusherConnectionHandlerFactory', 'idFlashFactory', 'idTransitionPrevented',
  ($rootScope,   $scope,   $state,   $cacheFactory,   usSpinnerService,   PusherService,   pusherConnectionHandlerFactory,   idFlashFactory,   idTransitionPrevented) ->
    idFlashFactory.scope = $scope
    $scope.flash = idFlashFactory

    # handle generic state change conditions
    transitionStart = ->
      usSpinnerService.spin('global-spinner')
      $rootScope.transitionInProgress = true
    transitionComplete = ->
      $rootScope.transitionInProgress = false
      usSpinnerService.stop('global-spinner')
    transitionError = (e) ->
      # todo: submit error to error collection tool
      console.error 'Error transitioning $state', e, $state.current
      # hmm: $stateChangeError seems to not be thrown when preventDefault is called
      # if e.message == 'transition prevented'
      #   # something called .preventDefault, probably the transitionGateway
      #   console.log 'todo: report transition prevented error to collection tool'
      transitionComplete()

    $rootScope.$on('$stateChangeStart', transitionStart)
    $rootScope.$on('$stateChangeSuccess', transitionComplete)
    $rootScope.$on('$stateChangeError', transitionError)

    # handle pusher app-specific events
    markPusherReady = ->
      p = $state.go('dialer.ready')
      p.catch(idTransitionPrevented)
    abortAllAndNotifyUser = ->
      # todo: implement
      console.log 'Unsupported browser...'

    $rootScope.$on('pusher:ready', markPusherReady)
    $rootScope.$on('pusher:bad_browser', abortAllAndNotifyUser)

    PusherService.then(pusherConnectionHandlerFactory.success,
                       pusherConnectionHandlerFactory.loadError)
])

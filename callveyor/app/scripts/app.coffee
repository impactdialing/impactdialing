'use strict'

callveyor = angular.module('callveyor', [
  'config',
  'ui.bootstrap',
  'ui.router',
  'doowb.angular-pusher',
  'idTwilio',
  'angularSpinner',
  'callveyor.dialer'
])

callveyor.config([
  'serviceTokens', 'idTwilioServiceProvider', 'PusherServiceProvider',
  (serviceTokens,   idTwilioServiceProvider,   PusherServiceProvider) ->
    console.log 'app config run: config = ', serviceTokens

    idTwilioServiceProvider.setScriptUrl('//static.twilio.com/libs/twiliojs/1.1/twilio.js')
    PusherServiceProvider.setPusherUrl('//d3dy5gmtp8yhk7.cloudfront.net/2.1/pusher.min.js')
    PusherServiceProvider.setToken(serviceTokens.pusher)
])

callveyor.controller('AppCtrl', [
  '$rootScope', '$scope', '$state', '$http', 'usSpinnerService', 'Pusher', 'idTwilioService'
  ($rootScope,   $scope,   $state,   $http,   usSpinnerService,   Pusher,   idTwilioService) ->
    console.log 'MainCtrl', $scope, $state
    console.log 'all states', $state.get()
    console.log 'dialer state', $state.get('dialer')

    transitionInProgress = -> usSpinnerService.spin('global-spinner')
    transitionComplete = -> usSpinnerService.stop('global-spinner')
    $rootScope.$on('$stateChangeStart', transitionInProgress)
    $rootScope.$on('$stateChangeSuccess', transitionComplete)
    $rootScope.$on('$stateChangeError', transitionComplete)

    tokensFetched = (resp) ->
      $rootScope.serviceConfig = {
        tokens: resp.data.tokens
      }
      $state.go('dialer.ready')
      # PusherServiceProvider.setToken(pusherToken)
      # idTwilioServiceProvider.setToken(twilioToken)

    $http.get('/call_center/api/service_tokens.json').then(tokensFetched)
])

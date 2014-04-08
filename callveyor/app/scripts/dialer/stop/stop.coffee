'use strict'

stop = angular.module('callveyor.dialer.stop', [])

stop.config([
  '$stateProvider'
  ($stateProvider) ->
    $stateProvider.state('dialer.stop', {
      views:
        callFlowButtons:
          templateUrl: "/callveyor/dialer/stop/callFlowButtons.tpl.html"
          controller: 'callFlowButtonsCtrl.stop'
        callStatus:
          templateUrl: '/callveyor/dialer/stop/callStatus.tpl.html'
          controller: 'callStatusCtrl.stop'
    })
])

stop.controller('callFlowButtonsCtrl.stop', [
  '$scope', '$state', '$cacheFactory', 'idTwilioService'
  ($scope,   $state,   $cacheFactory,   idTwilioService) ->
    console.log 'callFlowButtonsCtrl.stop', $scope

    _twilioCache = $cacheFactory.get('Twilio')
    connection = _twilioCache.get('connection')

    disconnect = (Twilio) ->
      Twilio.Device.disconnect(-> $state.go('dialer.ready'))
      connection.disconnect()

    idTwilioService.then(disconnect)
])

stop.controller('callStatusCtrl.stop', [
  '$scope',
  ($scope) ->
    console.log 'stop.callStatusCtrl', $scope
    stop = {}
    stop.callStatusText = 'Stopping...'
    $scope.stop = stop
])

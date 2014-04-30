'use strict'

stop = angular.module('callveyor.dialer.stop', [
  'ui.router'
])

stop.config([
  '$stateProvider'
  ($stateProvider) ->
    $stateProvider.state('dialer.stop', {
      views:
        callFlowButtons:
          templateUrl: "/callveyor/dialer/stop/callFlowButtons.tpl.html"
          controller: 'StopCtrl.buttons'
        callStatus:
          templateUrl: '/callveyor/dialer/stop/callStatus.tpl.html'
          controller: 'StopCtrl.status'
    })
])

stop.controller('StopCtrl.buttons', [
  '$scope', '$state', '$cacheFactory', '$http', 'idTwilioService', 'callStation',
  ($scope,   $state,   $cacheFactory,   $http,   idTwilioService,   callStation) ->
    _twilioCache = $cacheFactory.get('Twilio')
    connection   = _twilioCache.get('connection')
    caller_id    = callStation.data.caller.id
    stopPromise  = $http.post("/call_center/api/#{caller_id}/stop_calling")

    always = ->
      connection.disconnect()
      $state.go('dialer.ready')

    stopPromise.finally(always)
])

stop.controller('StopCtrl.status', [
  '$scope',
  ($scope) ->
    console.log 'stop.callStatusCtrl', $scope
    stop = {}
    stop.callStatusText = 'Stopping...'
    $scope.stop = stop
])

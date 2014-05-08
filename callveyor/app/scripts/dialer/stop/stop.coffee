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
  '$scope', '$state', 'TwilioCache', '$http', 'idTwilioService', 'callStation',
  ($scope,   $state,   TwilioCache,   $http,   idTwilioService,   callStation) ->
    connection   = TwilioCache.get('connection')
    caller_id    = callStation.data.caller.id
    params       = {}
    params.session_id = callStation.data.caller.session_id
    stopPromise  = $http.post("/call_center/api/#{caller_id}/stop_calling", params)

    whenDisconnected = ->
      p = $state.go('dialer.ready')
      p.catch(idTransitionPrevented)

    always = ->
      connection.disconnect(whenDisconnected)
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

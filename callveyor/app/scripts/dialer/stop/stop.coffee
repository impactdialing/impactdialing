'use strict'

stop = angular.module('callveyor.dialer.stop', [
  'ui.router',
  'idCacheFactories',
  'idTransition'
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
  '$scope', '$state', 'TwilioCache', '$http', 'idTwilioService', 'callStation', 'idTransitionPrevented'
  ($scope,   $state,   TwilioCache,   $http,   idTwilioService,   callStation,   idTransitionPrevented) ->
    connection   = TwilioCache.get('connection')
    caller_id    = callStation.caller.id
    params       = {}
    params.session_id = callStation.caller.session_id
    stopPromise  = $http.post("/call_center/api/#{caller_id}/stop_calling", params)

    goTo = {}
    goTo.ready = ->
      console.log 'going to "ready" $state'
      p = $state.go('dialer.ready')
      p.catch(idTransitionPrevented)
      if angular.isFunction(goTo.readyOff)
        goTo.readyOff()

    always = ->
      if connection? and connection.status() != 'offline'
        TwilioCache.put('disconnect_pending', true)
        goTo.readyOff = connection.disconnect(goTo.ready)
        connection.disconnectAll()
      else
        goToReady()

    stopPromise.finally(always)
])

stop.controller('StopCtrl.status', [
  '$scope',
  ($scope) ->
    stop = {}
    stop.callStatusText = 'Stopping...'
    $scope.stop = stop
])

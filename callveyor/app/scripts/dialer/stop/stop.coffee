'use strict'

stop = angular.module('callveyor.dialer.stop', [])

stop.config([
  '$stateProvider'
  ($stateProvider) ->
    $stateProvider.state('dialer.stop', {
      views:
        callFlowButtons:
          templateUrl: "/scripts/dialer/stop/callFlowButtons.tpl.html"
          controller: 'callFlowButtonsCtrl.stop'
        callStatus:
          templateUrl: '/scripts/dialer/stop/callStatus.tpl.html'
          controller: 'callStatusCtrl.stop'
    })
])

stop.controller('callFlowButtonsCtrl.stop', [
  '$scope', '$state',
  ($scope,   $state) ->
    console.log 'callFlowButtonsCtrl.stop', $scope
    $scope.dialer.stop ||= {}
    $state.go('dialer.ready')
    # disconnect caller
])

stop.controller('callStatusCtrl.stop', [
  '$scope',
  ($scope) ->
    console.log 'stop.callStatusCtrl', $scope
    $scope.dialer.stop ||= {}
    $scope.dialer.stop.callStatusText = 'Stopping...'
])

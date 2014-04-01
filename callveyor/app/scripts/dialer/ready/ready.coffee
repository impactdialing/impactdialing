'use strict'

ready = angular.module('callveyor.dialer.ready', [])

ready.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.ready', {
    views:
      callFlowButtons:
        templateUrl: '/scripts/dialer/ready/callFlowButtons.tpl.html'
        controller: 'callFlowButtonsCtrl.ready'
      callInPhone:
        templateUrl: '/scripts/dialer/ready/callInPhone.tpl.html'
        controller: 'callInPhoneCtrl.ready'
      callStatus:
        templateUrl: '/scripts/dialer/ready/callStatus.tpl.html'
        controller: 'callStatusCtrl.ready'
  })
])

ready.controller('callFlowButtonsCtrl.ready', [
  '$scope', '$state', 'callStation',
  ($scope,   $state,   callStation) ->
    console.log 'ready.callFlowButtonsCtrl', $scope
    ready = {}
    ready.startCallingText = "Requires a mic and snappy internet."
    ready.startCalling = ->
      console.log 'startCalling clicked', callStation.data
      p = $state.go('dialer.hold')
      s = (r) -> console.log 'success', r.stack, r.message
      e = (r) -> console.log 'error', r.stack, r.message
      c = (r) -> console.log 'notify', r.stack, r.message
      p.then(s,e,c)
    $scope.ready = ready
])

ready.controller('callInPhoneCtrl.ready', [
  '$scope', 'callStation',
  ($scope, callStation) ->
    console.log 'ready.callInPhoneCtrl', $scope.dialer
    ready = callStation.data
    $scope.ready = ready
])

ready.controller('callStatusCtrl.ready', [
  '$scope', 'callStation',
  ($scope, callStation) ->
    console.log 'ready.callStatusCtrl', $scope.dialer
])

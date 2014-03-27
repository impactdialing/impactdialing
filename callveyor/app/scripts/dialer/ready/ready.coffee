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
  '$scope', '$state', 'caller',
  ($scope,   $state,   caller) ->
    console.log 'ready.callFlowButtonsCtrl', $scope
    ready = {}
    ready.startCallingText = "Requires a mic and snappy internet."
    ready.startCalling = ->
      console.log 'startCalling clicked', caller.data
      p = $state.go('dialer.hold', caller.data)
      s = (r) -> console.log 'success', r.stack, r.message
      e = (r) -> console.log 'error', r.stack, r.message
      c = (r) -> console.log 'notify', r.stack, r.message
      p.then(s,e,c)
    $scope.ready = ready
])

ready.controller('callInPhoneCtrl.ready', [
  '$scope', 'caller',
  ($scope, caller) ->
    console.log 'ready.callInPhoneCtrl', $scope.dialer
    ready = caller.data
    $scope.ready = ready
])

ready.controller('callStatusCtrl.ready', [
  '$scope', 'caller',
  ($scope, caller) ->
    console.log 'ready.callStatusCtrl', $scope.dialer
])

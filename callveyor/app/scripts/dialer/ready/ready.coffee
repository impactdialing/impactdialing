'use strict'

ready = angular.module('callveyor.dialer.ready', [])

ready.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.ready', {
    resolve:
      caller: ($http) -> $http.get('/scripts/dialer/ready/ready.json')
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
    $scope.dialer.ready ||= {}
    angular.extend($scope.dialer.ready, {
      startCallingText: "Requires a mic and snappy internet."
    })

    $scope.dialer.ready.startCalling = ->
      console.log 'startCalling clicked', caller.data
      p = $state.go('dialer.hold', caller.data)
      s = (r) -> console.log 'success', r.stack, r.message
      e = (r) -> console.log 'error', r.stack, r.message
      c = (r) -> console.log 'notify', r.stack, r.message
      p.then(s,e,c)
])

ready.controller('callInPhoneCtrl.ready', [
  '$scope', 'caller',
  ($scope, caller) ->
    console.log 'ready.callInPhoneCtrl', $scope.dialer
    $scope.dialer.meta ||= {}
    angular.extend($scope.dialer.meta, caller.data)
])

ready.controller('callStatusCtrl.ready', [
  '$scope', 'caller',
  ($scope, caller) ->
    console.log 'ready.callStatusCtrl', $scope.dialer
    $scope.dialer.meta ||= {}
    angular.extend($scope.dialer.meta, caller.data)
])

ready.controller('CallScriptLoadCtrl', [
  '$scope', 'script',
  ($scope,   script) ->
    $scope.dialer.callScript = script.data
])
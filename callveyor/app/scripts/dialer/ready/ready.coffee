'use strict'

ready = angular.module('callveyor.dialer.ready', [])

ready.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.ready', {
    resolve:
      info: ($http) -> $http.get('/scripts/dialer/ready/ready.json')
    views:
      callFlowButtons:
        templateUrl: '/scripts/dialer/ready/callFlowButtons.tpl.html'
        controller: 'callFlowButtonsCtrl.ready'
      callStatus:
        templateUrl: '/scripts/dialer/ready/callStatus.tpl.html'
        controller: 'callStatusCtrl.ready'
  })
])

ready.controller('callFlowButtonsCtrl.ready', [
  '$scope', '$state', 'info',
  ($scope,   $state,   info) ->
    console.log 'ready.callFlowButtonsCtrl', $scope
    $scope.dialer.ready ||= {}
    angular.extend($scope.dialer.ready, {
      startCallingText: "Requires a mic and snappy internet."
    })

    $scope.dialer.ready.startCalling = ->
      console.log 'startCalling clicked', info.data
      p = $state.go('dialer.hold', info.data)
      s = (r) -> console.log 'success', r.stack, r.message
      e = (r) -> console.log 'error', r.stack, r.message
      c = (r) -> console.log 'notify', r.stack, r.message
      p.then(s,e,c)
])

ready.controller('callStatusCtrl.ready', [
  '$scope', 'info',
  ($scope, info) ->
    console.log 'ready.callStatusCtrl', $scope
    $scope.dialer.meta ||= {}
    angular.extend($scope.dialer.meta, info.data)
])

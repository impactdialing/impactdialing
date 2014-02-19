'use strict'

ready = angular.module('callveyor.dialer.ready', [])

ready.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.ready', {
    resolve:
      info: ($http) -> $http.get('/scripts/dialer/ready/ready.json')
    views:
      callFlowButtons:
        templateUrl: '/scripts/dialer/ready/ready.tpl.html'
        controller: 'DialerReadyCtrl'
  })
])

ready.controller('DialerReadyCtrl', [
  '$scope', 'info',
  ($scope, info) ->
    console.log 'before', $scope
    console.log 'info', info.data
    $scope.dialer.ready = info.data

    $scope.startCalling = ->
      console.log 'startCalling clicked'

    console.log 'after', $scope
])
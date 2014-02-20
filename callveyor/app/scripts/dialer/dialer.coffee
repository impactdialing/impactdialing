'use strict'

dialer = angular.module('callveyor.dialer', [
  'doowb.angular-pusher',
  'ui.router',
  'callveyor.dialer.ready',
  'callveyor.dialer.hold'
])

dialer.config(['$stateProvider', 'PusherServiceProvider', ($stateProvider, PusherServiceProvider) ->
  PusherServiceProvider
  $stateProvider.state('dialer', {
    views:
      dialer:
        templateUrl: '/scripts/dialer/dialer.tpl.html'
        controller: 'DialerCtrl'
  })
])

dialer.controller('DialerCtrl', ['$scope', '$state', ($scope, $state) ->
  console.log 'DialerCtrl', $scope
  console.log 'Known states', $state.get()
  $scope.dialer = {}
  $state.go('dialer.ready')
])

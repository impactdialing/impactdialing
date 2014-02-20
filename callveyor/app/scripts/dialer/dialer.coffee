'use strict'

dialer = angular.module('callveyor.dialer', [
  'doowb.angular-pusher',
  'ui.router',
  'callveyor.dialer.ready',
  'callveyor.dialer.hold',
  'callveyor.dialer.stop'
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

dialer.controller('ContactInfoCtrl', [
  '$scope', '$state', 'contact'
  ($scope,   $state,   contact) ->
    console.log 'ContactInfoCtrl', contact
    $scope.contact ||= {}
    $scope.contact._meta ||= {}
    $scope.contact._meta.collapse = false
    angular.extend($scope.contact, contact.data)
])

dialer.controller('ScriptCtrl', [
  '$scope', '$state',
  ($scope,   $state) ->
    console.log 'ScriptCtrl', $scope
])
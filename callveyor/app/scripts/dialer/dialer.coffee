'use strict'

dialer = angular.module('callveyor.dialer', [
  'callveyor.dialer.ready',
  'callveyor.dialer.hold',
  'callveyor.dialer.active',
  'callveyor.dialer.wrap',
  'callveyor.dialer.stop',
  'callveyor.dialer.survey',
  'callveyor.contact'
])

dialer.config(['$stateProvider', 'PusherServiceProvider', ($stateProvider, PusherServiceProvider) ->
  PusherServiceProvider
  $stateProvider.state('dialer', {
    abstract: true
    templateUrl: '/scripts/dialer/dialer.tpl.html'
    resolve:
      caller: ($http) -> $http.get('/scripts/dialer/ready/ready.json')
    controller: 'DialerCtrl'
  })
])

dialer.controller('DialerCtrl', [
  '$state', 'caller',
  ($state,   caller) ->
    console.log 'DialerCtrl', caller
])

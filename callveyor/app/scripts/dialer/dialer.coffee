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

dialer.config([
  '$stateProvider', 'idTwilioServiceProvider', 'PusherServiceProvider',
  ($stateProvider,   idTwilioServiceProvider,   PusherServiceProvider) ->
    idTwilioServiceProvider
    PusherServiceProvider
    $stateProvider.state('dialer', {
      abstract: true
      templateUrl: '/scripts/dialer/dialer.tpl.html'
      resolve:
        token: ($http) -> $http.get('/call_center/api/token.json')
      controller: 'DialerCtrl'
    })
])

dialer.controller('DialerCtrl', [
  '$state', 'token',
  ($state,   token) ->
    console.log 'DialerCtrl', token
])

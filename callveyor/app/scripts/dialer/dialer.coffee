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
        callStation: ($http) -> $http.post('/call_center/api/call_station.json')
      controller: 'DialerCtrl'
    })
])

dialer.controller('DialerCtrl', [
  '$state', 'callStation',
  ($state,   callStation) ->
    console.log 'DialerCtrl', callStation
])

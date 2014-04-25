'use strict'

dialer = angular.module('callveyor.dialer', [
  'callveyor.dialer.ready',
  'callveyor.dialer.hold',
  'callveyor.dialer.active',
  'callveyor.dialer.wrap',
  'callveyor.dialer.stop',
  'survey',
  'callveyor.contact',
  'callveyor.call_flow'
])

dialer.config([
  '$stateProvider',
  ($stateProvider) ->
    $stateProvider.state('dialer', {
      abstract: true
      templateUrl: '/scripts/dialer/dialer.tpl.html'
      resolve:
        callStation: ($http) -> $http.post('/call_center/api/call_station.json')
      controller: 'DialerCtrl'
    })
])

dialer.controller('DialerCtrl', [
  '$rootScope', '$cacheFactory', 'Pusher', 'CallFlowFactory', 'callStation',
  ($rootScope,   $cacheFactory,   Pusher,   CallFlowFactory,   callStation) ->
    callStationCache = $cacheFactory('callStation')
    callStationCache.put('data', callStation.data)
    channel = callStation.data.caller.session_key

    ## Bind app call flow handlers
    $rootScope.$on('survey:save:success', CallFlowFactory.survey.save.success)

    ## Bind Pusher call flow handlers
    Pusher.subscribe(channel, 'start_calling', CallFlowFactory.startCalling)
    Pusher.subscribe(channel, 'conference_started', CallFlowFactory.conferenceStarted)
    Pusher.subscribe(channel, 'caller_connected_dialer', CallFlowFactory.callerConnectedDialer)
    Pusher.subscribe(channel, 'caller_reassigned', CallFlowFactory.callerReassigned)
    Pusher.subscribe(channel, 'calling_voter', CallFlowFactory.callingVoter)
    Pusher.subscribe(channel, 'voter_connected', CallFlowFactory.voterConnected)
    Pusher.subscribe(channel, 'voter_connected_dialer', CallFlowFactory.voterConnectedDialer)
    Pusher.subscribe(channel, 'voter_disconnected', CallFlowFactory.voterDisconnected)
    Pusher.subscribe(channel, 'caller_disconnected', CallFlowFactory.callerDisconnected)
    Pusher.subscribe(channel, 'transfer_busy', CallFlowFactory.transferBusy)
    Pusher.subscribe(channel, 'transfer_connected', CallFlowFactory.transferConnected)
    Pusher.subscribe(channel, 'transfer_conference_ended', CallFlowFactory.transferConferenceEnded)
    Pusher.subscribe(channel, 'warm_transfer', CallFlowFactory.warmTransfer)
    Pusher.subscribe(channel, 'cold_transfer', CallFlowFactory.coldTransfer)
    Pusher.subscribe(channel, 'caller_kicked_off', CallFlowFactory.callerKickedOff)
])

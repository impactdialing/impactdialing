'use strict'

ready = angular.module('callveyor.dialer.ready', [
  'ui.router',
  'idTwilioConnectionHandlers',
  'idFlash'
])

ready.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.ready', {
    views:
      callFlowButtons:
        templateUrl: '/callveyor/dialer/ready/callFlowButtons.tpl.html'
        controller: 'ReadyCtrl.buttons'
      callInPhone:
        templateUrl: '/callveyor/dialer/ready/callInPhone.tpl.html'
        controller: 'ReadyCtrl.phone'
      callStatus:
        templateUrl: '/callveyor/dialer/ready/callStatus.tpl.html'
        controller: 'ReadyCtrl.status'
  })
])

ready.controller('ReadyCtrl.buttons', [
  '$scope', '$state', '$cacheFactory', 'callStation', 'idTwilioConnectionFactory', 'idFlashFactory'
  ($scope,   $state,   $cacheFactory,   callStation,   idTwilioConnectionFactory,   idFlashFactory) ->
    config = callStation.data

    twilioParams = {
      'PhoneNumber': config.call_station.phone_number,
      'campaign_id': config.campaign.id,
      'caller_id': config.caller.id,
      'session_key': config.caller.session_key
    }

    ready = {}
    ready.startCallingText = "Requires a mic and snappy internet."
    ready.startCalling = ->
      console.log 'startCalling clicked', callStation.data
      $scope.transitionInProgress = true
      idTwilioConnectionFactory.connect(twilioParams)

    $scope.ready = ready
])

ready.controller('ReadyCtrl.phone', [
  '$scope', 'callStation',
  ($scope, callStation) ->
    console.log 'ready.callInPhoneCtrl', $scope.dialer
    ready = callStation.data
    $scope.ready = ready
])

ready.controller('ReadyCtrl.status', [
  '$scope', 'callStation',
  ($scope, callStation) ->
    console.log 'ready.callStatusCtrl', $scope.dialer
])

'use strict'

ready = angular.module('callveyor.dialer.ready', [])

ready.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.ready', {
    views:
      callFlowButtons:
        templateUrl: '/callveyor/dialer/ready/callFlowButtons.tpl.html'
        controller: 'callFlowButtonsCtrl.ready'
      callInPhone:
        templateUrl: '/callveyor/dialer/ready/callInPhone.tpl.html'
        controller: 'callInPhoneCtrl.ready'
      callStatus:
        templateUrl: '/callveyor/dialer/ready/callStatus.tpl.html'
        controller: 'callStatusCtrl.ready'
  })
])

ready.controller('callFlowButtonsCtrl.ready', [
  '$scope', '$state', '$cacheFactory', 'callStation', 'idTwilioService', 'idFlashService'
  ($scope,   $state,   $cacheFactory,   callStation,   idTwilioService,   idFlashService) ->
    console.log 'ready.callFlowButtonsCtrl', $scope

    _twilioCache = $cacheFactory.get('Twilio') || $cacheFactory('Twilio')

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
      connectHandler = (connection) ->
        p = $state.go('dialer.hold')
        s = (r) -> console.log 'success', r.stack, r.message
        e = (r) -> console.log 'error', r.stack, r.message
        c = (r) -> console.log 'notify', r.stack, r.message
        p.then(s,e,c)
      readyHandler = (device) ->
        console.log 'twilio connection ready', device

      errorHandler = (error) ->
        console.log 'twilio connection error', error
        idFlashService.now('error', 'Browser phone could not connect to the call center. Please dial-in to continue.')

      bindAndConnect = (twilio) ->
        console.log twilio
        twilio.Device.connect(connectHandler)
        twilio.Device.ready(readyHandler)
        twilio.Device.error(errorHandler)
        connection = twilio.Device.connect(twilioParams)
        _twilioCache.put('connection', connection)

      setupError = (err) ->
        console.log 'idTwilioService error', err
        idFlashService.now('error', 'Browser phone setup failed. Please dial-in to continue.')

      idTwilioService.then(bindAndConnect, setupError)

    $scope.ready = ready
])

ready.controller('callInPhoneCtrl.ready', [
  '$scope', 'callStation',
  ($scope, callStation) ->
    console.log 'ready.callInPhoneCtrl', $scope.dialer
    ready = callStation.data
    $scope.ready = ready
])

ready.controller('callStatusCtrl.ready', [
  '$scope', 'callStation',
  ($scope, callStation) ->
    console.log 'ready.callStatusCtrl', $scope.dialer
])

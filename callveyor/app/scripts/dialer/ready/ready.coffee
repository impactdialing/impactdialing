'use strict'

ready = angular.module('callveyor.dialer.ready', [
  'ui.router',
  'ui.bootstrap',
  'idTwilioConnectionHandlers',
  'idFlash',
  'idCacheFactories'
])

ready.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.ready', {
    views:
      callFlowButtons:
        templateUrl: '/callveyor/dialer/ready/callFlowButtons.tpl.html'
        controller: 'ReadyCtrl.splash'
  })
])

ready.controller('ReadyCtrl.splashModal', [
  '$scope', '$state', '$modalInstance', 'CallStationCache', 'idTwilioConnectionFactory', 'idFlashFactory', 'idTransitionPrevented',
  ($scope,   $state,   $modalInstance,   CallStationCache,   idTwilioConnectionFactory,   idFlashFactory,   idTransitionPrevented) ->
    config = {
      caller: CallStationCache.get('caller')
      campaign: CallStationCache.get('campaign')
      call_station: CallStationCache.get('call_station')
    }

    twilioParams = {
      'PhoneNumber': config.call_station.phone_number,
      'campaign_id': config.campaign.id,
      'caller_id': config.caller.id,
      'session_key': config.caller.session_key
    }

    idTwilioConnectionFactory.afterConnected = ->
      p = $state.go('dialer.hold')
      p.catch(idTransitionPrevented)

    idTwilioConnectionFactory.afterError = ->
      p = $state.go('dialer.ready')
      p.catch(idTransitionPrevented)

    ready = config || {}
    ready.startCalling = ->
      $scope.transitionInProgress = true
      idTwilioConnectionFactory.connect(twilioParams)
      $modalInstance.close()

    $scope.ready = ready
])

ready.controller('ReadyCtrl.splash', [
  '$scope', '$rootScope', '$modal', '$window', 'idTwilioService', 'usSpinnerService',
  ($scope,   $rootScope,   $modal,   $window,   idTwilioService,   usSpinnerService) ->

    done = ->
      $rootScope.transitionInProgress = false
    err = ->
      done()
      throw Error("TwilioClient failed to load")

    idTwilioService.then(done, err)

    splash = {}

    splash.getStarted = ->
      openModal = $modal.open({
        templateUrl: '/callveyor/dialer/ready/splash.tpl.html',
        controller: 'ReadyCtrl.splashModal',
        size: 'lg'
      })

    $scope.splash = splash
])

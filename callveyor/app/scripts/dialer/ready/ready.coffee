'use strict'

ready = angular.module('callveyor.dialer.ready', [
  'ui.router',
  'ui.bootstrap',
  'idTwilioConnectionHandlers',
  'idFlash',
  'idDeviceDetect',
  'idCacheFactories'
])

ready.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.ready', {
    views:
      callFlowButtons:
        templateUrl: '/callveyor/dialer/ready/callFlowButtons.tpl.html'
        controller: 'ReadyCtrl.splash'
      callStatus:
        templateUrl: '/callveyor/dialer/ready/callStatus.tpl.html'
        controller: 'ReadyCtrl.status'
  })
])

ready.factory('ReadyEventHandlers', [
  '$rootScope',
  ($rootScope) ->
    handlers = {
      bindCloseModal: (event, modalInstance) ->
        if handlers.boundCloseModal?
          handlers.boundCloseModal()

        handlers.boundCloseModal = $rootScope.$on(event, -> modalInstance.close())
    }

    handlers
])

ready.controller('ReadyCtrl.status', [
  '$scope', 'CallStationCache',
  ($scope,   CallStationCache) ->
    ready          = {}
    ready.campaign = CallStationCache.get('campaign')
    $scope.ready   = ready
])

ready.factory('BrowserPhone', [
  '$state', 'CallStationCache', 'idTwilioConnectionFactory', 'idFlashFactory', 'idTransitionPrevented',
  ($state,   CallStationCache,   idTwilioConnectionFactory,   idFlashFactory,   idTransitionPrevented) ->
    factory = {}
    factory.config = ->
      {
        caller: CallStationCache.get('caller')
        campaign: CallStationCache.get('campaign')
        call_station: CallStationCache.get('call_station')
      }
    factory.start = ->
      config = factory.config()
      twilioParams = {
        'PhoneNumber': config.call_station.phone_number,
        'campaign_id': config.campaign.id,
        'caller_id': config.caller.id,
        'session_key': config.caller.session_key
      }

      idTwilioConnectionFactory.afterConnected = ->
        p = $state.go('dialer.hold')
        p.catch(idTransitionPrevented)

      idTwilioConnectionFactory.connect(twilioParams)

    factory
])

ready.controller('ReadyCtrl.splashModal', [
  '$scope', '$modalInstance', 'ReadyEventHandlers', 'BrowserPhone',
  ($scope,   $modalInstance,   ReadyEventHandlers,   BrowserPhone) ->
    config = BrowserPhone.config()
    # close modal when connected via std phone
    ReadyEventHandlers.bindCloseModal("#{config.caller.session_key}:start_calling", $modalInstance)

    ready = config || {}
    ready.startCalling = ->
      $scope.transitionInProgress = true
      BrowserPhone.start()

    $scope.ready = ready
])

ready.controller('ReadyCtrl.splash', [
  '$scope', '$rootScope', '$uibModal', '$window', '$http', 'idTwilioService', 'usSpinnerService', 'ErrorCache', 'idFlashFactory', 'BrowserPhone', 'idDeviceDetectFactory',
  ($scope,   $rootScope,   $uibModal,   $window,   $http,   idTwilioService,   usSpinnerService,   ErrorCache,   idFlashFactory,   BrowserPhone,   idDeviceDetectFactory) ->

    done = ->
      $rootScope.transitionInProgress = false
    err = ->
      done()
      throw Error("TwilioClient failed to load")

    idTwilioService.then(done, err)

    splash = {}

    splash.getStarted = ->
      if idDeviceDetectFactory.isAndroid()
        $scope.transitionInProgress = true
        BrowserPhone.start()
      else
        openModal = $uibModal.open({
          templateUrl: '/callveyor/dialer/ready/splash.tpl.html',
          controller: 'ReadyCtrl.splashModal',
          size: 'md'
        })

    splash.logout = ->
      promise = $http.post("/app/logout")
      suc = ->
        window.location.reload(true)
      err = (e) ->
        ErrorCache.put("logout.failed", e)
        idFlashFactory.now('danger', "Logout failed.")

      promise.then(suc,err)

    $scope.splash = splash
])

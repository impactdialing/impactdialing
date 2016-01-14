'use strict'

hold = angular.module('callveyor.dialer.hold', [
  'ui.router',
  'idCacheFactories'
])

hold.config([
  '$stateProvider'
  ($stateProvider) ->
    $stateProvider.state('dialer.hold', {
      views:
        callFlowButtons:
          templateUrl: "/callveyor/dialer/hold/callFlowButtons.tpl.html"
          controller: 'HoldCtrl.buttons'
        callStatus:
          templateUrl: '/callveyor/dialer/hold/callStatus.tpl.html'
          controller: 'HoldCtrl.status'
    })
])

hold.controller('HoldCtrl.buttons', [
  '$rootScope', '$scope', '$state', '$timeout', '$cacheFactory', 'callStation', 'HouseholdCache', 'idHttpDialerFactory', 'idFlashFactory', 'usSpinnerService', 'TwilioCache', 'FlashCache',
  ($rootScope,   $scope,   $state,   $timeout,   $cacheFactory,   callStation,   HouseholdCache,   idHttpDialerFactory,   idFlashFactory,   usSpinnerService,   TwilioCache,   FlashCache) ->
    holdCache = $cacheFactory.get('hold') || $cacheFactory('hold')
    hold = holdCache.get('sharedScope')
    unless hold?
      hold = {}
      holdCache.put('sharedScope', hold)

    hold.campaign = callStation.campaign
    hold.stopCalling = ->
      $state.go('dialer.stop')

    hold.reset = ->
      hold.callStatusText = 'Waiting to dial...'
      $scope.transitionInProgress = false

    hold.dial = ->
      # update status > 'Dialing...'
      params            = {}

      household         = HouseholdCache.get('data') || {}
      caller            = callStation.caller || {}
      params.session_id = caller.session_id
      params.phone      = household.phone

      idHttpDialerFactory.dialContact(caller.id, params)

      hold.callStatusText         = 'Dialing...'
      $scope.transitionInProgress = true

    hold.skip = ->
      params            = {}

      caller            = callStation.caller || {}
      params.session_id = caller.session_id

      hold.callStatusText         = 'Skipping...'
      $scope.transitionInProgress = true
      promise                     = idHttpDialerFactory.skipHousehold(caller.id, params)

      skipSuccess = (payload) ->
        if payload.data.campaign_out_of_leads
          TwilioCache.put('disconnect_pending', true)
          FlashCache.put('error', 'All numbers have been dialed! Please get in touch with your account admin for further instructions.')
          HouseholdCache.put('data', {})
          $rootScope.$broadcast('household:changed')
          p = $state.go('abort')
          p.catch(idTransitionPrevented)
          return

        HouseholdCache.put('data', payload.data)
        hold.callStatusText = 'Waiting to dial...'
        $scope.$emit('household:changed')
      skipErr = (errObj) ->
        $scope.transitionInProgress = false
        hold.callStatusText = 'Error skipping.'
        usSpinnerService.stop('global-spinner')
      always = ->
        $scope.transitionInProgress = false
        usSpinnerService.stop('global-spinner')

      promise.then(skipSuccess, skipErr).finally(always)

    $scope.hold ||= hold
])

hold.controller('HoldCtrl.status', [
  '$scope', '$cacheFactory', 'callStation'
  ($scope,   $cacheFactory,   callStation) ->
    holdCache = $cacheFactory.get('hold') || $cacheFactory('hold')
    hold = holdCache.get('sharedScope')
    unless hold?
      hold = {}
      holdCache.put('sharedScope', hold)

    switch callStation.campaign.type
      when 'Power', 'Predictive'
        hold.callStatusText = 'Dialing...'
        hold.callStatusWorking = true
      when 'Preview'
        hold.callStatusText = 'Waiting to dial...'
        hold.callStatusWorking = false

    $scope.hold = hold
])

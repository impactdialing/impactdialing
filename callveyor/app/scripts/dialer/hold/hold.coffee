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
  '$scope', '$state', '$timeout', '$cacheFactory', 'callStation', 'ContactCache', 'idHttpDialerFactory', 'idFlashFactory', 'usSpinnerService',
  ($scope,   $state,   $timeout,   $cacheFactory,   callStation,   ContactCache,   idHttpDialerFactory,   idFlashFactory,   usSpinnerService) ->
    holdCache = $cacheFactory.get('hold') || $cacheFactory('hold')
    hold = holdCache.get('sharedScope')
    unless hold?
      hold = {}
      holdCache.put('sharedScope', hold)

    hold.campaign = callStation.data.campaign
    hold.stopCalling = ->
      console.log 'stopCalling clicked'
      $state.go('dialer.stop')

    hold.dial = ->
      # update status > 'Dialing...'
      params            = {}

      contact           = (ContactCache.get('data') || {}).fields
      caller            = callStation.data.caller || {}
      params.session_id = caller.session_id
      params.voter_id   = contact.id

      idHttpDialerFactory.dialContact(caller.id, params)

      hold.callStatusText         = 'Dialing...'
      $scope.transitionInProgress = true

    hold.skip = ->
      params            = {}

      contact           = (ContactCache.get('data') || {}).fields
      caller            = callStation.data.caller || {}
      params.session_id = caller.session_id
      params.voter_id   = contact.id

      hold.callStatusText         = 'Skipping...'
      $scope.transitionInProgress = true
      promise                     = idHttpDialerFactory.skipContact(caller.id, params)

      skipSuccess = (payload) ->
        console.log 'skip success', payload
        ContactCache.put('data', payload.data)
        hold.callStatusText = 'Waiting to dial...'
        $scope.$emit('contact:changed')
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

    hold.callStatusText = switch callStation.data.campaign.type
                            when 'Power', 'Predictive'
                              'Dialing...'
                            when 'Preview'
                              'Waiting to dial...'

    $scope.hold = hold
])

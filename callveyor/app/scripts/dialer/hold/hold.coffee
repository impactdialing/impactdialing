'use strict'

hold = angular.module('callveyor.dialer.hold', [])

hold.config([
  '$stateProvider'
  ($stateProvider) ->
    $stateProvider.state('dialer.hold', {
      views:
        callFlowButtons:
          templateUrl: "/scripts/dialer/hold/callFlowButtons.tpl.html"
          controller: 'HoldCtrl'
        callStatus:
          templateUrl: '/scripts/dialer/hold/callStatus.tpl.html'
          controller: 'HoldCtrl'
    })
])

hold.controller('HoldCtrl', [
  '$scope', '$state', '$timeout'
  ($scope,   $state,   $timeout) ->
    console.log 'callFlowButtonsCtrl.hold', $scope
    hold ||= {}

    hold.callStatusText = switch $scope.dialer.meta.campaign.type
                            when 'Power', 'Predictive'
                              'Dialing...'
                            when 'Preview'
                              'Waiting to dial...'
                            else
                              'Oops! Please Report this problem.'

    hold.stopCalling = ->
      console.log 'stopCalling clicked'
      $state.go('dialer.stop')

    hold.dial = ->
      # update status > 'Dialing...'
      @callStatusText = 'Dialing...'
      fakeDial = ->
        p = $state.go('dialer.active')
        s = (r) -> console.log 'success', r.stack, r.message
        e = (r) -> console.log 'error', r.stack, r.message
        c = (r) -> console.log 'notify', r.stack, r.message
        p.then(s,e,c)
      $timeout(fakeDial, 3000)
      # POST /dial
      # then -> to 'active'
      # error -> update status > 'Error + explain, maybe try again'

    hold.skip = ->
      # update status > 'Skipping...'
      # POST /skip
      # then -> update contact
      # error -> update status > 'Error + explain, maybe try again'
    $scope.dialer.hold = hold
])

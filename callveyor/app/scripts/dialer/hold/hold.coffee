'use strict'

hold = angular.module('callveyor.dialer.hold', [])

hold.config([
  '$stateProvider'
  ($stateProvider) ->
    $stateProvider.state('dialer.hold', {
      views:
        callFlowButtons:
          templateUrl: "/scripts/dialer/hold/callFlowButtons.tpl.html"
          controller: 'HoldCtrl.buttons'
        callStatus:
          templateUrl: '/scripts/dialer/hold/callStatus.tpl.html'
          controller: 'HoldCtrl.status'
    })
])

hold.controller('HoldCtrl.buttons', [
  '$scope', '$state', '$timeout'
  ($scope,   $state,   $timeout) ->
    console.log 'HoldCtrl.buttons', $scope
    hold ||= {}
    $scope.dialer.hold ||= hold

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
    angular.extend($scope.dialer.hold, hold)
])

hold.controller('HoldCtrl.status', [
  '$scope',
  ($scope) ->
    console.log 'HoldCtrl', $scope
    hold ||= {}
    $scope.dialer.hold ||= hold

    hold.callStatusText = switch $scope.dialer.meta.campaign.type
                            when 'Power', 'Predictive'
                              'Dialing...'
                            when 'Preview'
                              'Waiting to dial...'
                            else
                              'Oops! Please Report this problem.'

    angular.extend($scope.dialer.hold, hold)
])

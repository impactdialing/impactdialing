'use strict'

active = angular.module('callveyor.dialer.active', [])

active.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.active', {
    views:
      callFlowButtons:
        templateUrl: '/scripts/dialer/active/callFlowButtons.tpl.html'
        controller: 'ActiveCtrl'
      callStatus:
        templateUrl: '/scripts/dialer/active/callStatus.tpl.html'
        controller: 'ActiveCtrl'
  })
])

active.controller('ActiveCtrl', [
  '$scope', '$state',
  ($scope,   $state) ->
    console.log 'ActiveCtrl', $scope.dialer
    $scope.dialer.active ||= {}

    $scope.dialer.active.hangup = ->
      console.log 'hangup clicked'
      p = $state.go('dialer.wrap')
      s = (r) -> console.log 'success', r.stack, r.message
      e = (r) -> console.log 'error', r.stack, r.message
      c = (r) -> console.log 'notify', r.stack, r.message
      p.then(s,e,c)
])

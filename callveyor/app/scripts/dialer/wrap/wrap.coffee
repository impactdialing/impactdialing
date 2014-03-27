'use strict'

wrap = angular.module('callveyor.dialer.wrap', [])

wrap.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.wrap', {
    views:
      callStatus:
        templateUrl: '/scripts/dialer/wrap/callStatus.tpl.html'
        controller: 'WrapCtrl'
      surveyButtons:
        templateUrl: '/scripts/dialer/wrap/surveyButtons.tpl.html'
        controller: 'WrapCtrl'
  })
])

wrap.controller('WrapCtrl', [
  '$scope', '$state',
  ($scope,   $state) ->
    console.log 'WrapCtrl', $scope.dialer
    wrap = {}

    wrap.stopCalling = ->
      console.log 'wrap.stopCalling'
      $state.go('dialer.hold')

    # $scope.dialer.wrap.hangup = ->
    #   console.log 'hangup clicked'
      # p = $state.go('dialer.wrap')
      # s = (r) -> console.log 'success', r.stack, r.message
      # e = (r) -> console.log 'error', r.stack, r.message
      # c = (r) -> console.log 'notify', r.stack, r.message
      # p.then(s,e,c)
    $scope.wrap = wrap
])

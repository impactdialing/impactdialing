'use strict'

hold = angular.module('callveyor.dialer.hold', [])

hold.config([
  '$stateProvider'
  ($stateProvider) ->
    $stateProvider.state('dialer.hold', {
      resolve:
        contact: ($http) -> $http.get('/scripts/dialer/contact/info.json')
      views:
        callFlowButtons:
          templateUrl: "/scripts/dialer/hold/callFlowButtons.tpl.html"
          controller: 'callFlowButtonsCtrl.hold'
        callStatus:
          templateUrl: '/scripts/dialer/hold/callStatus.tpl.html'
          controller: 'callStatusCtrl.hold'
        contact:
          templateUrl: '/scripts/dialer/contact/info.tpl.html'
          controller: 'ContactInfoCtrl'
        script:
          templateUrl: '/scripts/dialer/script/form.tpl.html'
          controller: 'ScriptCtrl'
    })
])

hold.controller('callFlowButtonsCtrl.hold', [
  '$scope', '$state',
  ($scope,   $state) ->
    console.log 'callFlowButtonsCtrl.hold', $scope
    $scope.dialer.hold ||= {}

    $scope.dialer.hold.isNotPreview = ->
      console.log 'dialer.hold.isNotPreview', $scope.dialer.meta.campaign
      $scope.dialer.meta.campaign.type != 'Preview'

    $scope.dialer.hold.stopCalling = ->
      console.log 'stopCalling clicked'
      $state.go('dialer.stop')
])

hold.controller('callStatusCtrl.hold', [
  '$scope',
  ($scope) ->
    console.log 'hold.callStatusCtrl', $scope
    $scope.dialer.hold ||= {}
    $scope.dialer.hold.callStatusText = switch $scope.dialer.meta.campaign.type
                                            when 'Power', 'Predictive'
                                              'Dialing...'
                                            when 'Preview'
                                              'Waiting to dial...'
                                            else
                                              'Oops! Please Report this problem.'
])

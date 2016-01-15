'use strict'

wrap = angular.module('callveyor.dialer.wrap', [])

wrap.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.wrap', {
    views:
      callStatus:
        templateUrl: '/callveyor/dialer/wrap/callStatus.tpl.html'
        controller: 'WrapCtrl.status'
      callFlowButtons:
        templateUrl: '/callveyor/dialer/wrap/callFlowButtons.tpl.html'
        controller: 'WrapCtrl.buttons'
  })
])

wrap.controller('WrapCtrl.status', [
  '$rootScope', '$scope', '$state', 'TwilioCache',
  ($rootScope,   $scope,   $state,   TwilioCache) ->
    wrap        = {}
    wrap.icon   = 'glyphicon-pause'
    wrap.status = 'Waiting for call results.'
    saveSuccess = false

    successStatus = ->
      saveSuccess = true
      wrap.status = 'Results saved.'
    doneStatus = (event, payload) ->
      if saveSuccess
        wrap.icon   = 'glyphicon-ok'
        if payload.andContinue
          wrap.status = 'Saved. Loading contact...'
        else
          wrap.status = 'Saved. Hanging up...'
          $state.go('dialer.ready')
      else
        wrap.icon   = 'glyphicon-exclamation-sign'
        wrap.status = 'Results failed to save.'

      saveSuccess = false

    $rootScope.$on('survey:save:success', successStatus)
    $rootScope.$on('survey:save:done', doneStatus)

    $scope.wrap = wrap
])

wrap.controller('WrapCtrl.buttons', [->])

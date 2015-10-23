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
    wrap.status = 'Waiting for call results.'
    saveSuccess = false

    successStatus = ->
      saveSuccess = true
      wrap.status = 'Results saved.'
    doneStatus = (event, payload) ->
      if saveSuccess
        if payload.andContinue
          wrap.status = 'Results saved. Waiting for next contact from server...'
        else
          wrap.status = 'Results saved. Hanging up...'
          $state.go('dialer.ready')
      else
        wrap.status = 'Results failed to save.'

      saveSuccess = false

    $rootScope.$on('survey:save:success', successStatus)
    $rootScope.$on('survey:save:done', doneStatus)

    $scope.wrap = wrap
])

wrap.controller('WrapCtrl.buttons', [->])

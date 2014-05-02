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

wrap.controller('WrapCtrl.status', [->])

wrap.controller('WrapCtrl.buttons', [->])

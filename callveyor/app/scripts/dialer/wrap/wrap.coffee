'use strict'

wrap = angular.module('callveyor.dialer.wrap', [])

wrap.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.wrap', {
    views:
      callStatus:
        templateUrl: '/scripts/dialer/wrap/callStatus.tpl.html'
        controller: 'WrapCtrl'
  })
])

wrap.controller('WrapCtrl', [->])

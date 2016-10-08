'use strict'

userMessages = angular.module('idFlash', [
  'idDeviceDetect'
])

userMessages.factory('idFlashFactory', [
  '$timeout', 'idDeviceDetectFactory',
  ($timeout,   idDeviceDetectFactory) ->
    flash = {
      alerts: []
      nowAndDismiss: (type, message, dismissIn, pile = true) ->
        # console.log('idFLashFactory.nowAndDismiss', type, message)
        if idDeviceDetectFactory.isMobile()
          alert(message)
        else
          obj = {type, message}
          if pile then flash.alerts.push(obj) else flash.alerts = [obj]
          autoDismiss = ->
            index = flash.alerts.indexOf(obj)
            flash.dismiss(index)
          $timeout(autoDismiss, dismissIn)
      now: (type, message, pile = true) ->
        # console.log('idFLashFactory.now', type, message)
        if idDeviceDetectFactory.isMobile()
          alert(message)
        else
          obj = {type, message}
          if pile then flash.alerts.push(obj) else flash.alerts = [obj]
      dismiss: (index) ->
        flash.alerts.splice(index, 1)
    }

    flash
])

userMessages.controller('idFlashCtrl', [
  '$scope', 'idFlashFactory',
  ($scope,   idFlashFactory) ->
    $scope.flash = idFlashFactory
])

userMessages.directive('idUserMessages', ->
  {
    restrict: 'A'
    templateUrl: '/callveyor/common/id_flash/id_flash.tpl.html'
    controller: 'idFlashCtrl'
  }
)

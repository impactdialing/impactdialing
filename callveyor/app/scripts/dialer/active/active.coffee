'use strict'

active = angular.module('callveyor.dialer.active', [
  'ui.router',
  'callveyor.dialer.active.transfer',
  'idFlash'
])

active.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.active', {
    views:
      callFlowButtons:
        templateUrl: '/callveyor/dialer/active/callFlowButtons.tpl.html'
        controller: 'ActiveCtrl.buttons'
      callStatus:
        templateUrl: '/callveyor/dialer/active/callStatus.tpl.html'
        controller: 'ActiveCtrl.status'
      callFlowDropdown:
        templateUrl: '/callveyor/dialer/active/transfer/dropdown.tpl.html'
        controller: 'TransferCtrl.list'
      transferContainer:
        templateUrl: '/callveyor/dialer/active/transfer/container.tpl.html'
        controller: 'TransferCtrl.container'
  })
])
active.controller('ActiveCtrl.status', [->])
active.controller('ActiveCtrl.buttons', [
  '$scope', '$state', '$http', '$cacheFactory', 'idFlashFactory',
  ($scope,   $state,   $http,   $cacheFactory,   idFlashFactory) ->
    console.log 'ActiveCtrl', $scope.dialer
    active = {}

    active.hangup = ->
      console.log 'hangup clicked'
      $scope.transitionInProgress = true
      callCache                   = $cacheFactory.get('call')

      # unless callCache?
      #   console.log 'report this problem'
      #   return

      call_id     = callCache.get('id')
      stopPromise = $http.post("/call_center/api/#{call_id}/hangup")

      success = ->
        e = (obj) ->
          # todo: submit to errorception
          console.log 'error transitioning to dialer.wrap', obj

        statePromise = $state.go('dialer.wrap')
        statePromise.catch(e)

      error = (resp) ->
        console.log 'error trying to stop calling', resp
        idFlashFactory.now('error', 'Error. Try again.')

      stopPromise.then(success, error)

    $scope.active = active
])


active.controller('TransferCtrl.container', [
  '$rootScope', '$scope',
  ($rootScope,   $scope) ->
    console.log 'TransferCtrl.container'

    $rootScope.rootTransferCollapse = false
])

active.controller('TransferCtrl.list', [
  '$scope', '$state', '$filter', '$cacheFactory', 'idFlashFactory',
  ($scope,   $state,   $filter,   $cacheFactory,   idFlashFactory) ->
    console.log 'TransferCtrl.list', $cacheFactory.get('transfer')

    transfer = {}
    transfer.cache = $cacheFactory.get('transfer')
    if transfer.cache?
      transfer.list = transfer.cache.get('list') || []
    else
      transfer.list = []
      console.log 'report the problem'

    transfer.select = (id) ->
      matchingID = (obj) -> id == obj.id
      targets = $filter('filter')(transfer.list, matchingID)
      if targets[0]?
        console.log 'target', targets[0]
        transfer.cache.put('selected', targets[0])

        if $state.is('dialer.active.transfer.selected')
          p = $state.go('dialer.active.transfer.reselect')
        else
          p = $state.go('dialer.active.transfer.selected')
        s = (r) -> console.log 'success', r.stack, r.message
        e = (r) -> console.log 'error', r.stack, r.message
        c = (r) -> console.log 'notify', r.stack, r.message
        p.then(s,e,c)
      else
        idFlashFactory.now('error', 'Error loading selected transfer. Please try again and Report problem if error continues.', 5000)

    $scope.transfer = transfer
])

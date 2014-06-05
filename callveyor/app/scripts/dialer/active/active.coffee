'use strict'

active = angular.module('callveyor.dialer.active', [
  'ui.router',
  'callveyor.dialer.active.transfer',
  'idFlash',
  'idCacheFactories'
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
  '$scope', '$state', '$http', 'CallCache', 'idFlashFactory',
  ($scope,   $state,   $http,   CallCache,   idFlashFactory) ->
    active = {}

    active.hangup = ->
      $scope.transitionInProgress = true

      call_id     = CallCache.get('id')
      # if not in active warm transfer
      ## hangup on voter
      stopPromise = $http.post("/call_center/api/#{call_id}/hangup")
      # if in active warm transfer
      ## disconnect caller but leave voter & transfer connected
      ## POST "/caller/:caller_id/kick?caller_session_id=1&participant_type=caller"

      success = ->
        e = (obj) ->
          # todo: submit to errorception
          console.log 'error transitioning to dialer.wrap', obj

        statePromise = $state.go('dialer.wrap')
        statePromise.catch(e)

      error = (resp) ->
        console.log 'error trying to stop calling', resp
        idFlashFactory.now('danger', 'Error. Try again.')

      stopPromise.then(success, error)

    $scope.active = active
])


active.controller('TransferCtrl.container', [
  '$rootScope', '$scope',
  ($rootScope,   $scope) ->
    $rootScope.rootTransferCollapse = false
])

active.controller('TransferCtrl.list', [
  '$scope', '$state', '$filter', 'TransferCache', 'idFlashFactory',
  ($scope,   $state,   $filter,   TransferCache,   idFlashFactory) ->
    transfer = {}
    transfer.cache = TransferCache
    if transfer.cache?
      transfer.list = transfer.cache.get('list') || []
    else
      transfer.list = []
      console.log 'report the problem'

    transfer.select = (id) ->
      matchingID = (obj) -> id == obj.id
      targets = $filter('filter')(transfer.list, matchingID)
      if targets[0]?
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
        idFlashFactory.now('danger', 'Error loading selected transfer. Please try again and Report problem if error continues.')

    $scope.transfer = transfer
])

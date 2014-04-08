'use strict'

active = angular.module('callveyor.dialer.active', [
  'callveyor.dialer.active.transfer'
])

active.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.active', {
    resolve:
      transfers: ($http) -> $http.get('/scripts/dialer/active/transfers.json')
    views:
      callFlowButtons:
        templateUrl: '/callveyor/dialer/active/callFlowButtons.tpl.html'
        controller: 'ActiveButtonCtrl'
      callStatus:
        templateUrl: '/callveyor/dialer/active/callStatus.tpl.html'
        controller: 'ActiveStatusCtrl'
      callFlowDropdown:
        templateUrl: '/callveyor/dialer/active/transfer/dropdown.tpl.html'
        controller: 'TransferListCtrl'
      transferContainer:
        templateUrl: '/callveyor/dialer/active/transfer/container.tpl.html'
        controller: 'TransferContainerCtrl'
  })
])
active.controller('ActiveStatusCtrl', [->])
active.controller('ActiveButtonCtrl', [
  '$scope', '$state', '$cacheFactory', 'transfers'
  ($scope,   $state,   $cacheFactory,   transfers) ->
    console.log 'ActiveCtrl', $scope.dialer
    active = {}

    active.hangup = ->
      console.log 'hangup clicked'
      p = $state.go('dialer.wrap')
      s = (r) -> console.log 'success', r.stack, r.message
      e = (r) -> console.log 'error', r.stack, r.message
      c = (r) -> console.log 'notify', r.stack, r.message
      p.then(s,e,c)

    $scope.active = active
])


active.controller('TransferContainerCtrl', [
  '$rootScope', '$scope',
  ($rootScope,   $scope) ->
    console.log 'TransferContainerCtrl'

    $rootScope.rootTransferCollapse = false
])

active.controller('TransferListCtrl', [
  '$scope', '$state', '$filter', '$cacheFactory', 'transfers',
  ($scope,   $state,   $filter,   $cacheFactory,   transfers) ->
    console.log 'TransferListCtrl', $cacheFactory.get('transfer')

    transfer = {}
    transfer.cache = $cacheFactory.get('transfer') || $cacheFactory('transfer')
    transfer.list = transfers.data
    transfer.select = (id) ->
      console.log 'transfer.select clicked', transfer.cache.info()
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

    $scope.transfer = transfer
])

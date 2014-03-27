'use strict'

active = angular.module('callveyor.dialer.active', [])

active.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.active', {
    resolve:
      transfers: ($http) -> $http.get('/scripts/dialer/active/transfers.json')
    views:
      callFlowButtons:
        templateUrl: '/scripts/dialer/active/callFlowButtons.tpl.html'
        controller: 'ActiveButtonCtrl'
      callStatus:
        templateUrl: '/scripts/dialer/active/callStatus.tpl.html'
        controller: 'ActiveStatusCtrl'
      callFlowDropdown:
        templateUrl: '/scripts/dialer/active/transfer/dropdown.tpl.html'
        controller: 'TransferListCtrl'
      transferContainer:
        templateUrl: '/scripts/dialer/active/transfer/container.tpl.html'
        controller: 'TransferContainerCtrl'
  })
  $stateProvider.state('dialer.active.transfer', {
    abstract: true
    views:
      transferPanel:
        templateUrl: '/scripts/dialer/active/transfer/panel.tpl.html'
        controller: 'TransferPanelCtrl'
  })
  $stateProvider.state('dialer.active.transfer.selected', {
    views:
      transferButtons:
        templateUrl: '/scripts/dialer/active/transfer/selected/buttons.tpl.html'
        controller: 'TransferButtonCtrl.selected'
      transferInfo:
        templateUrl: '/scripts/dialer/active/transfer/info.tpl.html'
        controller: 'TransferInfoCtrl'
  })
  # ideally the {reload} option or fn would work but there seems to be a bug:
  # http://angular-ui.github.io/ui-router/site/#/api/ui.router.state.$state
  # https://github.com/angular-ui/ui-router/issues/582
  $stateProvider.state('dialer.active.transfer.reselect', {
    views:
      transferButtons:
        templateUrl: '/scripts/dialer/active/transfer/selected/buttons.tpl.html'
        controller: 'TransferButtonCtrl.selected'
      transferInfo:
        templateUrl: '/scripts/dialer/active/transfer/info.tpl.html'
        controller: 'TransferInfoCtrl'
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

active.controller('TransferInfoCtrl', [
  '$scope', '$cacheFactory',
  ($scope,   $cacheFactory) ->
    console.log 'TransferInfoCtrl'

    cache = $cacheFactory.get('transfer')
    transfer = cache.get('selected')
    $scope.transfer = transfer
])
active.controller('TransferButtonCtrl.selected', [
  '$rootScope', '$scope', '$state', '$filter', '$cacheFactory',
  ($rootScope,   $scope,   $state,   $filter,   $cacheFactory) ->
    console.log 'TransferButtonCtrl.selected', $cacheFactory.get('transfer').info()

    transfer = {}
    transfer.callStatus = 'Ready'
    transfer.cache = $cacheFactory.get('transfer') || $cacheFactory('transfer')
    selected = transfer.cache.get('selected')
    transfer.type = selected.transfer_type
    transfer.label = selected.label
    transfer.phone_number = selected.phone_number
    transfer.dial = ->
      console.log 'dial'
      @callStatusText = 'Dialing...'
      usSpinnerService.spin('transfer-spinner')
      fakeDial = ->
        p = $state.go('dialer.active')
        s = (r) -> console.log 'success', r.stack, r.message
        e = (r) -> console.log 'error', r.stack, r.message
        c = (r) -> console.log 'notify', r.stack, r.message
        p.then(s,e,c)
      $timeout(fakeDial, 500)

    transfer.cancel = ->
      console.log 'cancel'
      transfer.cache.remove('selected')
      $state.go('dialer.active')

    console.log 'rootScope', $rootScope
    console.log 'collapse before', $rootScope.rootTransferCollapse
    $rootScope.rootTransferCollapse = false
    console.log 'collapse before', $rootScope.rootTransferCollapse
    $scope.transfer = transfer
])
active.controller('TransferContainerCtrl', [
  '$rootScope', '$scope',
  ($rootScope,   $scope) ->
    console.log 'TransferContainerCtrl'

    $rootScope.rootTransferCollapse = false
])
active.controller('TransferPanelCtrl', [
  '$scope', '$cacheFactory',
  ($scope,   $cacheFactory) ->
    console.log 'TransferPanelCtrl'

    transfer = {}
    transfer.callStatus = 'Ready to dial...'
    $scope.transfer = transfer
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

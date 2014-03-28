'use strict'

transfer = angular.module('callveyor.dialer.active.transfer', [])

transfer.config(['$stateProvider', ($stateProvider) ->
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

transfer.controller('TransferPanelCtrl', [
  '$scope', '$cacheFactory',
  ($scope,   $cacheFactory) ->
    console.log 'TransferPanelCtrl'

    transfer = {}
    transfer.callStatus = 'Ready to dial...'
    $scope.transfer = transfer
])

transfer.controller('TransferInfoCtrl', [
  '$scope', '$cacheFactory',
  ($scope,   $cacheFactory) ->
    console.log 'TransferInfoCtrl'

    cache = $cacheFactory.get('transfer')
    transfer = cache.get('selected')
    $scope.transfer = transfer
])

transfer.controller('TransferButtonCtrl.selected', [
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
      @cache.remove('selected')
      $state.go('dialer.active')

    console.log 'rootScope', $rootScope
    console.log 'collapse before', $rootScope.rootTransferCollapse
    $rootScope.rootTransferCollapse = false
    console.log 'collapse before', $rootScope.rootTransferCollapse
    $scope.transfer = transfer
])

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
  $stateProvider.state('dialer.active.transfer.conference', {
    views:
      transferInfo:
        templateUrl: '/scripts/dialer/active/transfer/info.tpl.html'
        controller: 'TransferInfoCtrl'
      transferButtons:
        templateUrl: '/scripts/dialer/active/transfer/conference/buttons.tpl.html'
        controller: 'TransferButtonCtrl.conference'
  })
])

transfer.controller('TransferPanelCtrl', [
  '$rootScope', '$scope', '$cacheFactory',
  ($rootScope,   $scope,   $cacheFactory) ->
    console.log 'TransferPanelCtrl'

    $rootScope.transferStatus = 'Ready to dial...'
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
  '$rootScope', '$scope', '$state', '$filter', '$cacheFactory', 'idHttpDialerFactory', 'usSpinnerService', 'callStation'
  ($rootScope,   $scope,   $state,   $filter,   $cacheFactory,   idHttpDialerFactory,   usSpinnerService,   callStation) ->
    console.log 'TransferButtonCtrl.selected', $cacheFactory.get('transfer').info()

    transfer       = {}
    transfer.cache = $cacheFactory.get('transfer') || $cacheFactory('transfer')
    selected       = transfer.cache.get('selected')
    transfer_type  = selected.transfer_type

    isWarmTransfer = -> transfer_type == 'warm'

    transfer.dial = ->
      console.log 'dial', $scope
      params                = {}
      contactCache          = $cacheFactory.get('contact')
      callCache             = $cacheFactory.get('call')
      contact               = (contactCache.get('data') || {}).fields
      caller                = callStation.data.caller || {}
      params.voter          = contact.id
      params.call           = callCache.get('id')
      params.caller_session = caller.session_id
      params.transfer       = {id: selected.id}

      p = idHttpDialerFactory.dialTransfer(params)

      $rootScope.transferStatus       = 'Dialing...'
      $rootScope.transitionInProgress = true
      usSpinnerService.spin('transfer-spinner')

      s = (o) ->
        $rootScope.transferStatus = 'Ringing...'
        console.log 'dial success', o
      e = (r) ->
        $rootScope.transferStatus = 'Error dialing.'
        console.log 'report this problem', r

      p.then(s,e)

    transfer.cancel = ->
      console.log 'cancel'
      @cache.remove('selected')
      $state.go('dialer.active')

    $rootScope.rootTransferCollapse = false
    $scope.transfer = transfer
])

transfer.controller('TransferButtonCtrl.conference', [
  '$rootScope', '$scope', '$state', '$cacheFactory', 'idHttpDialerFactory', 'usSpinnerService'
  ($rootScope,   $scope,   $state,   $cacheFactory,   idHttpDialerFactory,   usSpinnerService) ->
    console.log 'TransferButtonCtrl.conference'

    transfer = {}
    transfer.cache = $cacheFactory.get('transfer') || $cacheFactory('transfer')
    usSpinnerService.stop('transfer-spinner')
    $rootScope.transferStatus = 'Transfer on call'
    transfer.hangup = ->
      console.log 'transfer.hangup'
      p = $state.go('dialer.active')
      s = (o) -> console.log 'success', o
      e = (r) -> console.log 'error', e
      c = (n) -> console.log 'notify', n
      p.then(s,e,c)

    $scope.transfer = transfer
])

'use strict'

transfer = angular.module('callveyor.dialer.active.transfer', [])

transfer.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.active.transfer', {
    abstract: true
    views:
      transferPanel:
        templateUrl: '/callveyor/dialer/active/transfer/panel.tpl.html'
        controller: 'TransferPanelCtrl'
  })
  $stateProvider.state('dialer.active.transfer.selected', {
    views:
      transferButtons:
        templateUrl: '/callveyor/dialer/active/transfer/selected/buttons.tpl.html'
        controller: 'TransferButtonCtrl.selected'
      transferInfo:
        templateUrl: '/callveyor/dialer/active/transfer/info.tpl.html'
        controller: 'TransferInfoCtrl'
  })
  # ideally the {reload} option or fn would work but there seems to be a bug:
  # http://angular-ui.github.io/ui-router/site/#/api/ui.router.state.$state
  # https://github.com/angular-ui/ui-router/issues/582
  $stateProvider.state('dialer.active.transfer.reselect', {
    views:
      transferButtons:
        templateUrl: '/callveyor/dialer/active/transfer/selected/buttons.tpl.html'
        controller: 'TransferButtonCtrl.selected'
      transferInfo:
        templateUrl: '/callveyor/dialer/active/transfer/info.tpl.html'
        controller: 'TransferInfoCtrl'
  })
  $stateProvider.state('dialer.active.transfer.conference', {
    views:
      transferInfo:
        templateUrl: '/callveyor/dialer/active/transfer/info.tpl.html'
        controller: 'TransferInfoCtrl'
      transferButtons:
        templateUrl: '/callveyor/dialer/active/transfer/conference/buttons.tpl.html'
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
  '$scope', 'TransferCache',
  ($scope,   TransferCache) ->
    console.log 'TransferInfoCtrl'

    transfer        = TransferCache.get('selected')
    $scope.transfer = transfer
])

transfer.controller('TransferButtonCtrl.selected', [
  '$rootScope', '$scope', '$state', '$filter', 'TransferCache', 'CallCache', 'ContactCache', 'idHttpDialerFactory', 'usSpinnerService', 'callStation'
  ($rootScope,   $scope,   $state,   $filter,   TransferCache,   CallCache,   ContactCache,   idHttpDialerFactory,   usSpinnerService,   callStation) ->
    console.log 'TransferButtonCtrl.selected', TransferCache.info()

    transfer       = {}
    transfer.cache = TransferCache
    selected       = transfer.cache.get('selected')
    transfer_type  = selected.transfer_type

    isWarmTransfer = -> transfer_type == 'warm'

    transfer.dial = ->
      console.log 'dial', $scope
      params                = {}


      contact               = (ContactCache.get('data') || {}).fields
      caller                = callStation.data.caller || {}
      params.voter          = contact.id
      params.call           = CallCache.get('id')
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
      TransferCache.remove('selected')
      $state.go('dialer.active')

    $rootScope.rootTransferCollapse = false
    $scope.transfer = transfer
])

transfer.controller('TransferButtonCtrl.conference', [
  '$rootScope', '$scope', '$state', 'TransferCache', 'idHttpDialerFactory', 'usSpinnerService'
  ($rootScope,   $scope,   $state,   TransferCache,   idHttpDialerFactory,   usSpinnerService) ->
    console.log 'TransferButtonCtrl.conference'

    transfer = {}
    transfer.cache = TransferCache
    usSpinnerService.stop('transfer-spinner')
    $rootScope.transferStatus = 'Transfer on call'
    transfer.hangup = ->
      console.log 'transfer.hangup'
      # POST "/caller/:caller_id/kick?caller_session_id=1&participant_type=transfer"
      p = $state.go('dialer.active')
      s = (o) -> console.log 'success', o
      e = (r) -> console.log 'error', e
      c = (n) -> console.log 'notify', n
      p.then(s,e,c)

    $scope.transfer = transfer
])

'use strict'

transfer = angular.module('callveyor.dialer.active.transfer', [
  'ui.router',
  'callveyor.http_dialer',
  'idCacheFactories',
  'angularSpinner'
])

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
    $rootScope.transferStatus = 'Ready to dial...'
])

transfer.controller('TransferInfoCtrl', [
  '$scope', 'TransferCache',
  ($scope,   TransferCache) ->
    transfer        = TransferCache.get('selected')
    $scope.transfer = transfer
])

transfer.factory('TransferDialerEventFactory', [
  '$rootScope', 'usSpinnerService',
  ($rootScope,   usSpinnerService) ->
    handlers = {
      httpSuccess: ($event, resp) ->
        console.log 'http dialer success', resp
        usSpinnerService.stop('transfer-spinner')
        $rootScope.transitionInProgress = false
        $rootScope.transferStatus = resp.data.status
      httpError: ($event, resp) ->
        console.log 'http dialer error', resp
        usSpinnerService.stop('transfer-spinner')
        $rootScope.transitionInProgress = false
        $rootScope.transferStatus = 'Dial failed.'
    }

    $rootScope.$on('http_dialer:success', handlers.httpSuccess)
    $rootScope.$on('http_dialer:error', handlers.httpError)

    handlers
])

transfer.controller('TransferButtonCtrl.selected', [
  '$rootScope', '$scope', '$state', 'TransferCache', 'TransferDialerEventFactory', 'CallCache', 'ContactCache', 'idHttpDialerFactory', 'usSpinnerService', 'CallStationCache',
  ($rootScope,   $scope,   $state,   TransferCache,   TransferDialerEventFactory,   CallCache,   ContactCache,   idHttpDialerFactory,   usSpinnerService,   CallStationCache) ->
    transfer       = {}
    transfer.cache = TransferCache
    selected       = transfer.cache.get('selected')
    transfer_type  = selected.transfer_type

    isWarmTransfer = -> transfer_type == 'warm'

    transfer.dial = ->
      params                = {}

      contact                   = (ContactCache.get('data') || {}).fields
      caller                    = CallStationCache.get('caller')
      params.voter              = contact.id
      params.call               = CallCache.get('id')
      params.caller_session     = caller.session_id
      params.transfer           = {id: selected.id}
      $rootScope.transferStatus = 'Preparing to dial...'

      idHttpDialerFactory.dialTransfer(params)

      $rootScope.transitionInProgress = true
      usSpinnerService.spin('transfer-spinner')

    transfer.cancel = ->
      TransferCache.remove('selected')
      $state.go('dialer.active')

    $rootScope.rootTransferCollapse = false
    $scope.transfer = transfer
])

transfer.controller('TransferButtonCtrl.conference', [
  '$rootScope', '$scope', '$state', '$http', 'TransferCache', 'CallStationCache', 'idHttpDialerFactory', 'usSpinnerService', 'idFlashFactory'
  ($rootScope,   $scope,   $state,   $http,   TransferCache,   CallStationCache,   idHttpDialerFactory,   usSpinnerService,   idFlashFactory) ->
    transfer = {}
    transfer.cache = TransferCache
    usSpinnerService.stop('transfer-spinner')
    $rootScope.transferStatus = 'Transfer on call'
    transfer.hangup = ->
      caller                   = CallStationCache.get('caller')
      url                      = "/call_center/api/#{caller.id}/kick"
      params                   = {}
      params.caller_session_id = caller.session_id
      params.participant_type  = 'transfer'

      # POST "/caller/:caller_id/kick?caller_session_id=1&participant_type=transfer"
      promise = $http.post(url, params)
      error = (resp) ->
        $rootScope.transferStatus = "Transfer on call (hangup failed)"
      promise.catch(error)

    $scope.transfer = transfer
])

'use strict'

active = angular.module('callveyor.dialer.active', [
  'ui.router',
  'callveyor.dialer.active.transfer',
  'idFlash',
  'idCacheFactories',
  'callveyor.http_dialer'
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
  '$rootScope', '$scope', '$state', '$http', '$timeout', '$window', 'CallCache', 'TransferCache', 'CallStationCache', 'idFlashFactory', 'idHttpDialerFactory',
  ($rootScope,   $scope,   $state,   $http,   $timeout,   $window,   CallCache,   TransferCache,   CallStationCache,   idFlashFactory,   idHttpDialerFactory) ->
    active = {}

    permissions = CallStationCache.get('permissions')
    active.permissions = permissions

    active.hangup = ->
      $scope.transitionInProgress = true

      call_id  = CallCache.get('id')
      transfer = TransferCache.get('selected')
      caller   = CallStationCache.get('caller')
      promise  = idHttpDialerFactory.hangup(call_id, transfer, caller)

      success = ->
        statePromise = $state.go('dialer.wrap')
        statePromise.catch($window._errs.push)

      error = (resp) ->
        console.log 'error trying to stop calling', resp
        idFlashFactory.now('danger', 'Error hanging up. Try again.')
        $window._errs.push(resp)

      promise.then(success, error)

    active.dropMessage = ->
      return unless active.permissions.can_drop_message_manually == true

      $scope.transitionInProgress = true

      call_id     = CallCache.get('id')
      promise     = idHttpDialerFactory.dropMessage(call_id)

      success = (resp) ->
        console.log 'success requesting to drop message', resp

        boundEvents = []
        caller      = CallStationCache.get('caller')

        idFlashFactory.nowAndDismiss('info', 'Preparing message drop...', 3000)

        # warning: possible issue w/ this timeout algorithm. seems that occasionally, the timeout
        # will not be cleared despite message_drop_error|success having fired.
        timeoutReached = ->
          obj = new Error("Client timeout reached. Message drop queued successfully. Completion message not received.")
          $window._errs.push(obj)
          idFlashFactory.nowAndDismiss('warning', 'Message drop outcome unclear.', 3000)
          $scope.transitionInProgress = false

        timeoutPromise = $timeout(timeoutReached, 10000)

        deregisterEvents = ->
          while fn = boundEvents.pop()
            fn()

        cancel = (deregisterEvent) ->
          $timeout.cancel(timeoutPromise)
          deregisterEvents()

        boundEvents.push($rootScope.$on("#{caller.session_key}:message_drop_error", cancel))
        boundEvents.push($rootScope.$on("#{caller.session_key}:message_drop_success", cancel))

      error = (resp) ->
        console.log 'error dropping message', resp
        idFlashFactory.now('danger', 'Error preparing message drop. Try again.')
        $window._errs.push(resp)
        $scope.transitionInProgress = false

      promise.then(success, error)

    $scope.active = active
])


active.controller('TransferCtrl.container', [
  '$rootScope', '$scope',
  ($rootScope,   $scope) ->
    $rootScope.rootTransferCollapse = false
])

active.controller('TransferCtrl.list', [
  '$scope', '$state', '$filter', '$window', 'TransferCache', 'idFlashFactory',
  ($scope,   $state,   $filter,   $window,   TransferCache,   idFlashFactory) ->
    transfer = {}
    transfer.cache = TransferCache
    if transfer.cache?
      transfer.list = transfer.cache.get('list') || []
    else
      transfer.list = []
      err = new Error("TransferCtrl.list running but TransferCache is undefined.")
      $window._errs.push(err)

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
        p.then(s,$window._errs.push)
      else
        idFlashFactory.now('danger', 'Error loading selected transfer. Please try again and report problem if error continues.')

    $scope.transfer = transfer
])

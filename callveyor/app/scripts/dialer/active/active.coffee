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

      call_id      = CallCache.get('id')
      caller       = CallStationCache.get('caller')
      selected     = TransferCache.get('selected')
      hangupMethod = TransferCache.get('hangup_method')
      if selected? and selected.wasDialed
        hangupMethod = 'kick'
      promise      = idHttpDialerFactory.hangup(call_id, hangupMethod, caller)

      success = ->
        statePromise = $state.go('dialer.wrap')
        TransferCache.remove('hangup_method')

      error = (resp) ->
        idFlashFactory.now('danger', 'Error hanging up. Try again.')
        $window.Bugsnag.notifyException("Error hanging up.", {
          diagnostics: {
            response: resp
          }
        })

      promise.then(success, error)

    active.dropMessage = ->
      return unless active.permissions.can_drop_message_manually == true

      $scope.transitionInProgress = true

      call_id     = CallCache.get('id')
      promise     = idHttpDialerFactory.dropMessage(call_id)

      success = (resp) ->
        boundEvents = []
        caller      = CallStationCache.get('caller')

        idFlashFactory.nowAndDismiss('info', 'Preparing message drop...', 3000)

        # warning: possible issue w/ this timeout algorithm. seems that occasionally, the timeout
        # will not be cleared despite message_drop_error|success having fired.
        timeoutReached = ->
          obj = new Error("Client timeout reached. Message drop queued successfully. Completion message not received.")
          console.log 'timeoutReached'
          $window.Bugsnag.notifyException(obj)
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
        $window.Bugsnag.notifyException("Error preparing message drop.", {
          diagnostics: {
            response: resp
          }
        })
        idFlashFactory.now('danger', 'Error preparing message drop. Try again.')
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
      Bugsnag.notifyException(err)

    transfer.select = (id) ->
      previousSelection = transfer.cache.get('selected')
      if previousSelection and previousSelection.wasDialed
        console.log('previousSelection wasDialed')
        return false
      matchingID = (obj) -> id == obj.id
      targets = $filter('filter')(transfer.list, matchingID)
      if targets[0]?
        transfer.cache.put('selected', targets[0])

        if $state.is('dialer.active.transfer.selected')
          p = $state.go('dialer.active.transfer.reselect')
        else
          p = $state.go('dialer.active.transfer.selected')
        p.catch(Bugsnag.notifyException)
      else
        idFlashFactory.now('danger', 'Error loading selected transfer. Please try again and report problem if error continues.')

    $scope.transfer = transfer
])

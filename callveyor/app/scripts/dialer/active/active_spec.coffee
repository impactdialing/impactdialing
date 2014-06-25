describe 'dialer.active', ->
  $stateFake  = {}
  $timeout    = {}
  $window     = {}
  dialerFake  = {}
  flashFake   = {}
  spinnerFake = {}
  transfers   = [
    {id: 12, label: 'Rep. Kansas, Joe', phone: '5553224542'},
    {id: 15, label: 'Rep. Kentucky, Jack', phone: '5552526426'}
  ]
  call = {
    id: 42
  }
  caller = {
    id: 2
    session_id: 12
    session_key: 'caller-session-key-1234'
  }
  permissions = {
    can_drop_message_manually: true
  }

  beforeEach module 'callveyor.dialer.active', ($provide) ->
    ->
      $provide.value('$state', $stateFake)
      $provide.value('idHttpDialerFactory', dialerFake)
      $provide.value('idFlashFactory', flashFake)
      $provide.value('usSpinnerService', spinnerFake)

  describe 'ActiveCtrl.buttons', ->
    $rootScope       = ''
    $scope           = ''
    $state           = ''
    $cacheFactory    = ''
    $httpBackend     = ''
    $controller      = ''
    $timeout         = ''
    TransferCache    = ''
    CallCache        = ''
    CallStationCache = ''

    beforeEach(inject(
      (_$rootScope_, _$state_, _$cacheFactory_, _$httpBackend_, _$controller_, _$timeout_, _$window_, _TransferCache_, _CallCache_, _CallStationCache_) ->
        $rootScope       = _$rootScope_
        $scope           = $rootScope
        $state           = _$state_
        $window          = _$window_
        $timeout         = _$timeout_
        $cacheFactory    = _$cacheFactory_
        $httpBackend     = _$httpBackend_
        $controller      = _$controller_
        TransferCache    = _TransferCache_
        CallCache        = _CallCache_
        CallStationCache = _CallStationCache_
        $state.go        = jasmine.createSpy('-$state.go spy-').andReturn($state)
        $state.catch     = jasmine.createSpy('-$statePromise spy-')
        $window._errs    = {
          push: jasmine.createSpy('-errorception _errs.push spy-')
        }

        TransferCache.put('selected', transfers[0])
        CallCache.put('id', call.id)
        CallStationCache.put('caller', caller)
        CallStationCache.put('permissions', permissions)
        $controller('ActiveCtrl.buttons', {$scope, transfers})
    ))

    describe '$scope.active.hangup()', ->

      beforeEach ->
        dialerFake.then   = jasmine.createSpy('-idHttpDialerFactoryPromise spy-')
        dialerFake.hangup = jasmine.createSpy('-idHttpDialerFactory.hangup spy-').andReturn(dialerFake)
        $cacheFactory.get('Call').put('id', call.id)

      it 'calls idHttpDialerFactory.hangup(call_id, transfer, caller)', ->
        $scope.active.hangup()
        expect(dialerFake.hangup).toHaveBeenCalledWith(call.id, transfers[0], caller)

      it 'transitions to dialer.wrap', ->
        dialerFake.then.andCallFake(-> dialerFake.then.calls[0].args[0]())
        $scope.active.hangup()

        expect($state.go).toHaveBeenCalledWith('dialer.wrap')

    describe '$scope.active.dropMessage', ->
      beforeEach ->
        dialerFake.then        = jasmine.createSpy('-idHttpDialerFactoryPromise spy-')
        dialerFake.dropMessage = jasmine.createSpy('-idHttpDialerFactory.dropMessage spy-').andReturn(dialerFake)
        $cacheFactory.get('Call').put('id', call.id)

      describe 'when active.permissions.can_drop_message_manually === false (permissions obj comes from CallStationCache)', ->
        it 'returns early', ->
          permissions.can_drop_message_manually = false
          $scope.active.dropMessage()
          expect(dialerFake.dropMessage).not.toHaveBeenCalled()

      describe 'when active.permissions.can_drop_message_manually === true', ->
        beforeEach ->
          permissions.can_drop_message_manually = true

        it 'sets transitionInProgress to true', ->
          $scope.active.dropMessage()
          expect($scope.transitionInProgress).toBeTruthy()

        it 'tells idHttpDialerFactory to dropMessage(call_id) (call_id comes from CallCache)', ->
          $scope.active.dropMessage()
          expect(dialerFake.dropMessage).toHaveBeenCalledWith(call.id)

        describe 'idHttpDialerFactory.dropMessage completes successfully', ->
          beforeEach ->
            flashFake.nowAndDismiss = jasmine.createSpy('-flashFake.nowAndDismiss spy-')
            $scope.active.dropMessage()
            dialerFake.then.mostRecentCall.args[0]()

          it 'displays a info message to user for a few seconds', ->
            expect(flashFake.nowAndDismiss).toHaveBeenCalledWith('info', jasmine.any(String), jasmine.any(Number))

          it 'sets an outcome timeout of 10 seconds -- when reached, submit error, display warning & set transitionInProgress to false', ->
            $timeout.flush()
            expect($window._errs.push).toHaveBeenCalled()
            expect(flashFake.nowAndDismiss).toHaveBeenCalledWith('warning', jasmine.any(String), jasmine.any(Number))
            expect($scope.transitionInProgress).toBeFalsy()

          angular.forEach(["message_drop_success", "message_drop_error"], (ev) ->
            describe "#{ev} event received before outcome timeout reached", ->
              beforeEach ->
                $rootScope.$broadcast("#{caller.session_key}:#{ev}")

              it 'cancels the timeout', ->
                $timeout.verifyNoPendingTasks()
                expect($window._errs.push).not.toHaveBeenCalled()
                expect(flashFake.nowAndDismiss).not.toHaveBeenCalledWith('warning', jasmine.any(String), jasmine.any(Number))
                expect($scope.transitionInProgress).toBeTruthy()

              it 'removes handlers for message_drop_error and message_drop_success', ->
                $timeout.cancel = jasmine.createSpy('-$timeout.cancel spy-')
                $rootScope.$broadcast("#{caller.session_key}:#{ev}")
                expect($timeout.cancel).not.toHaveBeenCalled()
          )

        describe 'idHttpDialerFactory.dropMessage completes with error', ->
          beforeEach ->
            flashFake.now = jasmine.createSpy('-flashFake.nowAndDismiss spy-')
            $scope.active.dropMessage()
            dialerFake.then.mostRecentCall.args[1]()

          it 'displays error message', ->
            expect(flashFake.now).toHaveBeenCalledWith('danger', jasmine.any(String))

          it 'submits error to errorception', ->
            expect($window._errs.push).toHaveBeenCalled()

          it 'sets transitionInProgress to false', ->
            expect($scope.transitionInProgress).toBeFalsy()


  describe 'TransferCtrl.container', ->
    $rootScope = ''
    $scope     = ''
    beforeEach(inject(
      (_$rootScope_, _$controller_) ->
        $rootScope  = _$rootScope_
        $scope      = $rootScope
        $controller = _$controller_

        $controller('TransferCtrl.container', {$scope})
    ))

    it 'sets $rootScope.rootTransferCollapse to false', ->
      expect($rootScope.rootTransferCollapse).toBeDefined()
      expect($rootScope.rootTransferCollapse).toBeFalsy()

  describe 'TransferCtrl.list', ->
    $rootScope    = ''
    $scope        = ''
    $state        = ''
    $cacheFactory = ''
    $httpBackend  = ''
    $controller   = ''

    beforeEach(inject(
      (_$rootScope_, _$state_, _$cacheFactory_, _$httpBackend_, _$controller_) ->
        $rootScope    = _$rootScope_
        $scope        = $rootScope
        $state        = _$state_
        $cacheFactory = _$cacheFactory_
        $httpBackend  = _$httpBackend_
        $controller   = _$controller_
        $state.go     = jasmine.createSpy('-$state.go spy-').andReturn($state)
        $state.then  = jasmine.createSpy('-$statePromise spy-')

        $controller('TransferCtrl.list', {$scope})
    ))

    it 'loads $cacheFactory.get("transfer") to $scope.transfer.cache', ->
      expect($cacheFactory.get('Transfer')).toBeDefined()
      expect($scope.transfer.cache).toEqual($cacheFactory.get('Transfer'))

    it 'loads $cacheFactory.get("transfer").get("list") to $scope.transfer.list', ->
      $cacheFactory.get('Transfer').put('list', transfers)
      $controller('TransferCtrl.list', {$scope})
      expect($scope.transfer.list).toEqual(transfers)

    it 'sets $scope.transfer.list to [] when $cacheFactory.get("transfer") is undefined', ->
      expect($scope.transfer.list).toEqual([])

    describe '$scope.transfer.select(id)', ->
      describe 'a match in $scope.transfer.list is found', ->
        beforeEach ->
          $state.is     = jasmine.createSpy('-$state.is spy-').andReturn(false)
          $cacheFactory.get('Transfer').put('list', transfers)
          $controller('TransferCtrl.list', {$scope})

        it 'puts the first match in the list to $cacheFactory("transfer").put("list")', ->
          $scope.transfer.select(transfers[0].id)
          cache = $cacheFactory.get('Transfer')
          expect(cache.get('selected')).toEqual(transfers[0])

        it 'transitions to dialer.active.transfer.(re)selected', ->
          $scope.transfer.select(transfers[0].id)
          expect($state.go).toHaveBeenCalledWith('dialer.active.transfer.selected')

      describe 'a match in $scope.transfer.list is NOT found', ->
        beforeEach ->
          flashFake.now = jasmine.createSpy('-idFlashFactory.now spy-')
          $controller('TransferCtrl.list', {$scope})

        it 'displays an error to the user, that self-destructs in some seconds', ->
          $scope.transfer.select(9999999)
          expect(flashFake.now.calls.length).toEqual(1)
          expect(flashFake.now).toHaveBeenCalledWith('danger', jasmine.any(String))

        it 'does not transition anywhere', ->
          $scope.transfer.select(9999999)
          expect($state.go).not.toHaveBeenCalled()

        it 'files a bug report'

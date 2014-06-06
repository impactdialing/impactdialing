describe 'dialer.active', ->
  $stateFake  = {}
  dialerFake  = {}
  flashFake   = {}
  spinnerFake = {}
  transfers = [
    {id: 12, label: 'Rep. Kansas, Joe', phone: '5553224542'},
    {id: 15, label: 'Rep. Kentucky, Jack', phone: '5552526426'}
  ]
  call = {
    id: 42
  }
  caller = {
    id: 2
    session_id: 12
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
    TransferCache    = ''
    CallCache        = ''
    CallStationCache = ''

    beforeEach(inject(
      (_$rootScope_, _$state_, _$cacheFactory_, _$httpBackend_, _$controller_, _TransferCache_, _CallCache_, _CallStationCache_) ->
        $rootScope       = _$rootScope_
        $scope           = $rootScope
        $state           = _$state_
        $cacheFactory    = _$cacheFactory_
        $httpBackend     = _$httpBackend_
        $controller      = _$controller_
        TransferCache    = _TransferCache_
        CallCache        = _CallCache_
        CallStationCache = _CallStationCache_
        $state.go        = jasmine.createSpy('-$state.go spy-').andReturn($state)
        $state.catch     = jasmine.createSpy('-$statePromise spy-')

        TransferCache.put('selected', transfers[0])
        CallCache.put('id', call.id)
        CallStationCache.put('caller', caller)
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

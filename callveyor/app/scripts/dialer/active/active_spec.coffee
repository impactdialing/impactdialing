describe 'dialer.active', ->
  $stateFake  = {}
  dialerFake  = {}
  flashFake   = {}
  spinnerFake = {}
  transfers = [
    {id: 12, label: 'Rep. Kansas, Joe', phone: '5553224542'},
    {id: 15, label: 'Rep. Kentucky, Jack', phone: '5552526426'}
  ]

  beforeEach module 'callveyor.dialer.active', ($provide) ->
    ->
      $provide.value('$state', $stateFake)
      $provide.value('idHttpDialerFactory', dialerFake)
      $provide.value('idFlashFactory', flashFake)
      $provide.value('usSpinnerService', spinnerFake)

  describe 'ActiveCtrl.buttons', ->
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
        $state.go     = jasmine.createSpy('-$state.go spy-').and.returnValue($state)
        $state.catch  = jasmine.createSpy('-$statePromise spy-')

        $controller('ActiveCtrl.buttons', {$scope, transfers})
    ))

    describe '$scope.active.hangup()', ->
      call = {
        id: 42
      }

      beforeEach ->
        $cacheFactory('call').put('id', call.id)
        $httpBackend.whenPOST("/call_center/api/#{call.id}/hangup").respond(200)

      it 'POSTs to /call_center/api/#{$cacheFactory.get("call").get("id")}/hangup', ->
        $httpBackend.expectPOST("/call_center/api/#{call.id}/hangup").respond(200)
        $scope.active.hangup()
        $httpBackend.verifyNoOutstandingExpectation()

      it 'transitions to dialer.wrap', ->
        $scope.active.hangup()
        $httpBackend.flush()
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
        $state.go     = jasmine.createSpy('-$state.go spy-').and.returnValue($state)
        $state.then  = jasmine.createSpy('-$statePromise spy-')

        $controller('TransferCtrl.list', {$scope})
    ))

    it 'loads $cacheFactory.get("transfer") to $scope.transfer.cache', ->
      expect($scope.transfer.cache).toEqual($cacheFactory.get('transfer'))

    it 'loads $cacheFactory.get("transfer").get("list") to $scope.transfer.list', ->
      $cacheFactory('transfer').put('list', transfers)
      $controller('TransferCtrl.list', {$scope})
      expect($scope.transfer.list).toEqual(transfers)

    it 'sets $scope.transfer.list to [] when $cacheFactory.get("transfer") is undefined', ->
      expect($scope.transfer.list).toEqual([])

    describe '$scope.transfer.select(id)', ->
      describe 'a match in $scope.transfer.list is found', ->
        beforeEach ->
          $state.is     = jasmine.createSpy('-$state.is spy-').and.returnValue(false)
          $cacheFactory('transfer').put('list', transfers)
          $controller('TransferCtrl.list', {$scope})

        it 'puts the first match in the list to $cacheFactory("transfer").put("list")', ->
          $scope.transfer.select(transfers[0].id)
          cache = $cacheFactory.get('transfer')
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
          expect(flashFake.now.calls.count()).toEqual(1)
          expect(flashFake.now).toHaveBeenCalledWith('error', jasmine.any(String), jasmine.any(Number))

        it 'does not transition anywhere', ->
          $scope.transfer.select(9999999)
          expect($state.go).not.toHaveBeenCalled()

        it 'files a bug report'

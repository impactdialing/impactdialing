describe 'callveyor.dialer.active.transfer module', ->
  $rootScope       = ''
  $scope           = ''
  $controller      = ''
  $httpBackend     = ''
  TransferCache    = ''
  ContactCache     = ''
  CallStationCache = ''
  usSpinnerService = ''
  idFlashFactory   = ''

  beforeEach(module('callveyor.dialer.active.transfer'))

  beforeEach(inject((_$rootScope_, _$httpBackend_, _$controller_, _TransferCache_, _ContactCache_, _CallStationCache_, _usSpinnerService_, _idFlashFactory_) ->
      $rootScope       = _$rootScope_
      $scope           = $rootScope
      $httpBackend     = _$httpBackend_
      $controller      = _$controller_
      TransferCache    = _TransferCache_
      ContactCache     = _ContactCache_
      CallStationCache = _CallStationCache_
      usSpinnerService = _usSpinnerService_
      idFlashFactory   = _idFlashFactory_
  ))

  describe 'TransferButtonCtrl.selected', ->

    describe '$scope.transfer.dial()', ->
      transfer = {
        id: 1
        transfer_type: 'warm'
      }
      contact = {
        fields: {
          id: 1
        }
      }
      caller = {
        session_id: 12
      }
      dial_response = {
        data: {
          type: transfer.transfer_type
          status: 'Ringing'
        }
      }
      beforeEach ->
        spyOn(usSpinnerService, 'spin')
        spyOn(usSpinnerService, 'stop')
        TransferCache.put('selected', transfer)
        ContactCache.put('data', contact)
        CallStationCache.put('caller', caller)
        $controller('TransferButtonCtrl.selected', {$scope})

      it 'sets $rootScope.transitionInProgress to true', ->
        $scope.transfer.dial()
        expect($rootScope.transitionInProgress).toBeTruthy()

      it 'spins the transfer-spinner', ->
        $scope.transfer.dial()
        expect(usSpinnerService.spin).toHaveBeenCalledWith('transfer-spinner')

      it 'sets $rootScope.transferStatus to "Preparing to dial...', ->
        $scope.transfer.dial()
        expect($rootScope.transferStatus).toEqual('Preparing to dial...')

      describe '$http request succeeds', ->
        describe 'dial attempt succeeds', ->
          beforeEach ->
            $httpBackend.whenPOST("/call_center/api/transfer/dial").respond(200, dial_response)

          it 'sets $rootScope.transferStatus to response.data.status', ->
            $scope.transfer.dial()
            $httpBackend.flush()
            expect($rootScope.transferStatus).toEqual(dial_response.status)

        describe 'dial attempt fails', ->
          beforeEach ->
            angular.extend(dial_response, {status: 'Busy'})
            $httpBackend.whenPOST("/call_center/api/transfer/dial").respond(200, dial_response)

          it 'sets $rootScope.transferStatus to response.data.status', ->
            $scope.transfer.dial()
            $httpBackend.flush()
            expect($rootScope.transferStatus).toEqual(dial_response.status)

      describe '$http request fails', ->
        beforeEach ->
          $httpBackend.whenPOST("/call_center/api/transfer/dial").respond(400, {})
        it 'sets $rootScope.transferStatus to "Dial failed."', ->
          $scope.transfer.dial()
          $httpBackend.flush()
          expect($rootScope.transferStatus).toEqual('Dial failed.')

  describe 'TransferButtonCtrl.conference', ->
    transfer = {
      id: 1
      transfer_type: 'warm'
    }
    caller = {
      id: 42
      session_id: 12
    }
    params = {
      participant_type: 'transfer'
      caller_session_id: caller.session_id
    }
    beforeEach ->
      spyOn(idFlashFactory, 'now')
      spyOn(usSpinnerService, 'spin')
      spyOn(usSpinnerService, 'stop')
      TransferCache.put('selected', transfer)
      CallStationCache.put('caller', caller)
      $controller('TransferButtonCtrl.conference', {$scope})
    describe '$scope.transfer.hangup', ->
      it 'makes $http request to kick transfer participant from conference', ->
        $httpBackend.expectPOST("/call_center/api/#{caller.id}/kick", params).respond(200, {})
        $scope.transfer.hangup()
        $httpBackend.flush()
        $httpBackend.verifyNoOutstandingExpectation()

      describe '$http request fails', ->
        it 'sets $rootScope.transferStatus to "Transfer on call (hangup failed)"', ->
          $httpBackend.whenPOST("/call_center/api/#{caller.id}/kick", params).respond(404, {})
          $scope.transfer.hangup()
          $httpBackend.flush()
          $httpBackend.verifyNoOutstandingRequest()
          expect($scope.transferStatus).toEqual("Transfer on call (hangup failed)")


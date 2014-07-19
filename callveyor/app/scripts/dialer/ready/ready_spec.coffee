describe 'dialer.ready', ->
  $stateFake  = {}
  twilioFake  = {}
  flashFake   = {}
  spinnerFake = {}
  callStation = {
    caller: {
      id: 42
      session_id: 12
      session_key: 'caller-session-key'
    }
    campaign: {
      id: 18
      type: 'Power'
    }
    call_station: {
      phone_number: '5552341958'
    }
  }
  modalInstanceFake = {
    close: jasmine.createSpy('-$modalInstance.close spy-')
  }
  modalFake = {
    open: jasmine.createSpy('-$modal.open spy-')
  }

  beforeEach module('callveyor.dialer.ready', ($provide) ->
    ->
      $provide.value('$state', $stateFake)
      $provide.value('idTwilioConnectionFactory', twilioFake)
      $provide.value('idFlashFactory', flashFake)
      $provide.value('usSpinnerService', spinnerFake)
      $provide.value('$modalInstance', modalInstanceFake)
      $provide.value('$modal', modalFake)
  )

  describe 'ReadyCtrl.splashModal', ->
    $rootScope       = ''
    $scope           = ''
    $state           = ''
    $cacheFactory    = ''
    $httpBackend     = ''
    $controller      = ''
    $modalInstance   = ''
    CallStationCache = ''

    beforeEach(inject(
      (_$rootScope_, _$state_, _$cacheFactory_, _$httpBackend_, _$controller_, _$modalInstance_, _CallStationCache_) ->
        $rootScope         = _$rootScope_
        $scope             = $rootScope
        $controller        = _$controller_
        $state             = _$state_
        $httpBackend       = _$httpBackend_
        $cacheFactory      = _$cacheFactory_
        $modalInstance     = _$modalInstance_
        CallStationCache   = _CallStationCache_
        $state.go          = jasmine.createSpy('-$state.go spy-')
        twilioFake.connect = jasmine.createSpy('-idTwilioConnectionFactory.connect spy-')
    ))

    describe '$scope.ready.startCalling() when idTwilioService resolves', ->
      twilioParams = {
        'PhoneNumber': callStation.call_station.phone_number
        'campaign_id': callStation.campaign.id
        'caller_id': callStation.caller.id
        'session_key': callStation.caller.session_key
      }

      beforeEach ->
        CallStationCache.put('caller', callStation.caller)
        CallStationCache.put('campaign', callStation.campaign)
        CallStationCache.put('call_station', callStation.call_station)
        $controller('ReadyCtrl.splashModal', {$scope})

      it 'sets $scope.transitionInProgress to true', ->
        expect($scope.transitionInProgress).toBeFalsy()
        $scope.ready.startCalling()
        expect($scope.transitionInProgress).toBeTruthy()

      it 'calls idTwilioConnectionFactory.connect(twilioParams)', ->
        $scope.ready.startCalling()
        expect(twilioFake.connect).toHaveBeenCalledWith(twilioParams)

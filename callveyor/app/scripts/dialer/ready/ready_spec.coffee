describe 'dialer.ready', ->
  $stateFake  = {}
  twilioFake  = {}
  flashFake   = {}
  spinnerFake = {}
  callStation = {
    data: {
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
  }

  beforeEach module('callveyor.dialer.ready', ($provide) ->
    ->
      $provide.value('$state', $stateFake)
      $provide.value('idTwilioConnectionFactory', twilioFake)
      $provide.value('idFlashFactory', flashFake)
      $provide.value('usSpinnerService', spinnerFake)
  )

  describe 'ReadyCtrl.buttons', ->
    $rootScope    = ''
    $scope        = ''
    $state        = ''
    $cacheFactory = ''
    $httpBackend  = ''
    $controller   = ''

    beforeEach(inject(
      (_$rootScope_, _$state_, _$cacheFactory_, _$httpBackend_, _$controller_) ->
        $rootScope            = _$rootScope_
        $scope                = $rootScope
        $controller           = _$controller_
        $state                = _$state_
        $httpBackend          = _$httpBackend_
        $cacheFactory         = _$cacheFactory_

        $state.go          = jasmine.createSpy('-$state.go spy-')
        twilioFake.connect = jasmine.createSpy('-idTwilioConnectionFactory.connect spy-')
    ))

    describe '$scope.ready.startCalling() when idTwilioService resolves', ->
      twilioParams = {
        'PhoneNumber': callStation.data.call_station.phone_number
        'campaign_id': callStation.data.campaign.id
        'caller_id': callStation.data.caller.id
        'session_key': callStation.data.caller.session_key
      }

      beforeEach ->
        $controller('ReadyCtrl.buttons', {$scope, callStation})

      it 'sets $scope.transitionInProgress to true', ->
        expect($scope.transitionInProgress).toBeFalsy()
        $scope.ready.startCalling()
        expect($scope.transitionInProgress).toBeTruthy()

      it 'calls idTwilioConnectionFactory.connect(twilioParams)', ->
        $scope.ready.startCalling()
        expect(twilioFake.connect).toHaveBeenCalledWith(twilioParams)

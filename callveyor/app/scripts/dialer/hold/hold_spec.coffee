describe 'dialer.hold', ->
  $stateFake  = {}
  dialerFake  = {}
  flashFake   = {}
  spinnerFake = {}
  callStation = {
    data: {
      caller: {
        id: 42
        session_id: 12
      }
      campaign: {
        type: 'Power'
      }
    }
  }
  contact = {
    data: {
      fields: {
        id: 9
      }
    }
  }

  beforeEach module('callveyor.dialer.hold', ($provide) ->
    ->
      $provide.value('$state', $stateFake)
      $provide.value('idHttpDialerFactory', dialerFake)
      $provide.value('idFlashFactory', flashFake)
      $provide.value('usSpinnerService', spinnerFake)
  )

  describe 'HoldCtrl.buttons', ->
    $rootScope    = ''
    $scope        = ''
    $state        = ''
    $cacheFactory = ''
    $controller   = ''

    beforeEach(inject(
      (_$rootScope_, _$state_, _$cacheFactory_, _$controller_) ->
        $rootScope             = _$rootScope_
        $scope                 = $rootScope
        $controller            = _$controller_
        $state                 = _$state_
        $cacheFactory          = _$cacheFactory_
        $state.go              = jasmine.createSpy('-$state.go spy-')
        dialerFake.dialContact = jasmine.createSpy('-idHttpDialerFactory.dialContact spy-')
        flashFake.now          = jasmine.createSpy('-idFlashFactory.now spy-')

        $controller('HoldCtrl.buttons', {$scope, callStation})
    ))

    it 'assigns callStation.data.campaign to $scope.hold.campaign', ->
      expect($scope.hold.campaign).toEqual(callStation.data.campaign)

    describe '$scope.hold.stopCalling()', ->
      it 'transitions to dialer.stop', ->
        $scope.hold.stopCalling()
        expect($state.go).toHaveBeenCalledWith('dialer.stop')

    describe '$scope.hold.dial()', ->
      describe '$cacheFactory("contact") exists and has "data"', ->
        beforeEach ->
          $cacheFactory('contact').put('data', contact.data)

        it 'updates status message', ->
          curStatus = $scope.hold.callStatusText
          $scope.hold.dial()
          expect($scope.hold.callStatusText).not.toEqual(curStatus)

        it 'sets $scope.transitionInProgress to true', ->
          expect($scope.transitionInProgress).toBeFalsy()
          $scope.hold.dial()
          expect($scope.transitionInProgress).toBeTruthy()

        it 'calls idHttpDialerFactory.dialContact(caller_id, {session_id: Num, voter_id: Num})', ->
          caller_id = callStation.data.caller.id
          params = {
            voter_id: contact.data.fields.id
            session_id: callStation.data.caller.session_id
          }
          $scope.hold.dial()
          expect(dialerFake.dialContact).toHaveBeenCalledWith(caller_id, params)

describe 'dialer.stop', ->
  $stateFake  = {}
  twilioFake  = {}
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

  beforeEach module('callveyor.dialer.stop', ($provide) ->
    ->
      $provide.value('$state', $stateFake)
      $provide.value('idTwilioService', twilioFake)
      $provide.value('idFlashFactory', flashFake)
      $provide.value('usSpinnerService', spinnerFake)
  )

  describe 'HoldCtrl.buttons', ->
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

        $httpBackend.whenPOST("/call_center/api/#{callStation.data.caller.id}/stop_calling").respond(200)
        $state.go             = jasmine.createSpy('-$state.go spy-')

        twilioFake.connection = {
          disconnect: jasmine.createSpy('-twilioFake.connection.disconnect spy-')
        }
        $cacheFactory('Twilio').put('connection', twilioFake.connection)

        $controller('StopCtrl.buttons', {$scope, callStation})
    ))

    it 'POSTs to /call_center/api/:caller_id/stop_calling w/ session_id param', ->
      params = {session_id: callStation.data.caller.session_id}
      $httpBackend.expectPOST("/call_center/api/#{callStation.data.caller.id}/stop_calling", params).respond(200)
      $controller('StopCtrl.buttons', {$scope, callStation})
      $httpBackend.flush()
      $httpBackend.verifyNoOutstandingExpectation()

    it 'always calls connection.disconnect() on $cacheFactory.get("Twilio").get("connection")', ->
      $httpBackend.flush()
      expect(twilioFake.connection.disconnect).toHaveBeenCalled()

    it 'always transitions to dialer.ready', ->
      $httpBackend.flush()
      $httpBackend.verifyNoOutstandingRequest()
      expect($state.go).toHaveBeenCalledWith('dialer.ready')

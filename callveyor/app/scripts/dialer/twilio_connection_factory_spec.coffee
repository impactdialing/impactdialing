describe 'idTwilioConnectionHandlers', ->
  $rootScope     = {}
  $fakeState     = {}
  $scope         = {}
  $state         = {}
  $cacheFactory  = {}
  factory        = {}
  idFlashFactory = {}
  callStation    = {
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

  beforeEach module 'idTwilioConnectionHandlers'

  beforeEach inject (_$injector_) ->
    $injector      = _$injector_
    $rootScope     = $injector.get('$rootScope')
    $scope         = $rootScope
    $cacheFactory  = $injector.get('$cacheFactory')
    $state         = $injector.get('$state')
    factory        = $injector.get('idTwilioConnectionFactory')
    idFlashFactory = $injector.get('idFlashFactory')

    idFlashFactory.now = jasmine.createSpy('-idFlashFactory.now spy-')
    $state.go          = jasmine.createSpy('-$state.go spy-').and.returnValue($state)
    $state.catch       = jasmine.createSpy('-$statePromise.catch spy-')

  describe 'connected(connection)', ->
    it 'stores connection in $cacheFactory("Twilio").put("connection")', ->
      connection = {name: 'Twilio connection instance'}
      factory.connected(connection)
      expect($cacheFactory.get('Twilio').get('connection')).toEqual(connection)

    it 'transitions to dialer.hold', ->
      factory.connected({})
      expect($state.go).toHaveBeenCalledWith('dialer.hold')

  describe 'error(error)', ->
    it 'displays an error to user, that self-destructs in some seconds', ->
      factory.error({message: 'Bad twilio', stack: {}})
      expect(idFlashFactory.now).toHaveBeenCalledWith('error', jasmine.any(String), jasmine.any(Number))

  describe 'resolved(twilio)', ->
    twilio = {}
    twilioParams = {
      'PhoneNumber': callStation.data.call_station.phone_number
      'campaign_id': callStation.data.campaign.id
      'caller_id': callStation.data.caller.id
      'session_key': callStation.data.caller.session_key
    }
    beforeEach ->
      twilio.then = jasmine.createSpy('-idTwilioService.then spy-')
      twilio.Device = {
        connect: jasmine.createSpy('-Twilio.Device.connect spy-')
        ready: jasmine.createSpy('-Twilio.Device.ready spy-')
        error: jasmine.createSpy('-Twilio.Device.error spy-')
      }
      factory.connect(twilioParams)

    it 'registers Twilio.Device.connect,error handlers', ->
      factory.resolved(twilio)
      expect(twilio.Device.connect).toHaveBeenCalledWith(jasmine.any(Function))
      expect(twilio.Device.error).toHaveBeenCalledWith(jasmine.any(Function))

    it 'calls Twilio.Device.connect(twilioParams)', ->
      factory.resolved(twilio)
      expect(twilio.Device.connect).toHaveBeenCalledWith(twilioParams)

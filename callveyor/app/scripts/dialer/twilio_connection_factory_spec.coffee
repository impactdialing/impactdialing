describe 'idTwilioConnectionHandlers', ->
  $rootScope     = {}
  $fakeState     = {}
  $scope         = {}
  $state         = {}
  $cacheFactory  = {}
  $window        = {}
  factory        = {}
  idFlashFactory = {}
  idTwilioConfig = {}
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
    $window        = $injector.get('$window')
    factory        = $injector.get('idTwilioConnectionFactory')
    idFlashFactory = $injector.get('idFlashFactory')
    idTwilioConfig = $injector.get('idTwilioConfig')
    $window._errs  = {
      push: jasmine.createSpy('-$window._errs.push spy-')
    }
    idFlashFactory.now = jasmine.createSpy('-idFlashFactory.now spy-')
    $state             = jasmine.createSpyObj('$state', ['go', 'catch'])
    $state.go.andReturn($state)
    idTwilioConfig.fetchToken = jasmine.createSpy('-idTwilioConfig.fetchToken spy-')

  describe 'connected(connection)', ->
    it 'stores connection in $cacheFactory("Twilio").put("connection")', ->
      connection = {name: 'Twilio connection instance'}
      factory.connected(connection)
      expect($cacheFactory.get('Twilio').get('connection')).toEqual(connection)

    it 'calls afterConnected if defined', ->
      factory.afterConnected = jasmine.createSpy('-afterConnected spy-')
      factory.connected({})
      expect(factory.afterConnected).toHaveBeenCalled()

  describe 'error(error)', ->
    it 'displays an error to user, that self-destructs in some seconds', ->
      factory.error({message: 'Bad twilio', stack: {}})
      expect(idFlashFactory.now).toHaveBeenCalledWith('danger', jasmine.any(String))

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
      twilio.Device = jasmine.createSpyObj('twilio.Device', ['connect', 'ready', 'error', 'disconnect'])
      factory.connect(twilioParams)

    it 'registers Twilio.Device.connect,error handlers', ->
      factory.resolved(twilio)
      expect(twilio.Device.connect).toHaveBeenCalledWith(jasmine.any(Function))
      expect(twilio.Device.error).toHaveBeenCalledWith(jasmine.any(Function))

    it 'calls Twilio.Device.connect(twilioParams)', ->
      factory.resolved(twilio)
      expect(twilio.Device.connect).toHaveBeenCalledWith(twilioParams)

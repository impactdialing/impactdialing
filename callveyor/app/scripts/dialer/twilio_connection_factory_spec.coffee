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
    it 'returns early when error.code == 31205 (Twilio Token Expired), we ignore this error because it happens frequently and we generate tokens each time calling is initiated', ->
      factory.error({message: 'Token Expired', code: 31205, stack: {}})
      expect($window._errs.push).not.toHaveBeenCalled()

  describe 'resolved(twilio)', ->
    twilio = {}
    twilioParams = {
      'PhoneNumber': callStation.call_station.phone_number
      'campaign_id': callStation.campaign.id
      'caller_id': callStation.caller.id
      'session_key': callStation.caller.session_key
    }
    beforeEach ->
      twilio.then = jasmine.createSpy('-idTwilioService.then spy-')
      twilio.Device = jasmine.createSpyObj('twilio.Device', ['connect', 'ready', 'error', 'disconnect'])
      factory.connect(twilioParams)

    it 'registers Twilio.Device.connect,error handlers', ->
      factory.resolved(twilio)
      expect(twilio.Device.connect).toHaveBeenCalledWith(jasmine.any(Function))
      expect(twilio.Device.error).toHaveBeenCalledWith(jasmine.any(Function))

    it 'fetches a new twilio capability token', ->
      factory.resolved(twilio)
      expect(idTwilioConfig.fetchToken).toHaveBeenCalled()

    it 'connects once twilio capability token fetch is successful', ->
      factory.resolved(twilio)
      idTwilioConfig.fetchToken.calls[0].args[0]()
      expect(twilio.Device.connect).toHaveBeenCalledWith(twilioParams)

camelCase = (str) ->
  all = while str.indexOf('_') != -1
    i = str.indexOf('_')
    st = str[i] + str[i+1]
    str = str.replace(st, str[i+1].toUpperCase())
  all[all.length - 1]

class FakePusher
  constructor: -> console.log 'FakePusher init'

pusherEvents = ['start_calling', 'conference_started', 'caller_connected_dialer',
                'caller_reassigned', 'calling_voter', 'voter_connected', 'voter_connected_dialer',
                'voter_disconnected', 'caller_disconnected', 'transfer_busy', 'transfer_connected',
                'transfer_conference_ended', 'contact_joined_transfer_conference', 'caller_joined_transfer_conference', 'caller_kicked_off']

describe 'callveyor.dialer module', ->
  callStation   = {
    caller: {
      session_key: 'caller-session-key'
    }
  }

  beforeEach module('callveyor.dialer', ($provide) ->
    ->
      $provide.value('Pusher', FakePusher)
  )

  describe 'DialerCtrl', ->
    $rootScope          = ''
    $scope              = $rootScope
    $state              = ''
    $cacheFactory       = ''
    $httpBackend        = ''
    $controller         = ''
    idCallFlow          = ''
    transitionValidator = ''

    beforeEach(inject(
      (_$rootScope_, _$state_, _$cacheFactory_, _$httpBackend_, _$controller_, _idCallFlow_, _transitionValidator_) ->
        $rootScope                     = _$rootScope_
        $scope                         = $rootScope
        $state                         = _$state_
        $cacheFactory                  = _$cacheFactory_
        $httpBackend                   = _$httpBackend_
        $controller                    = _$controller_
        idCallFlow                     = _idCallFlow_
        transitionValidator            = _transitionValidator_
        transitionValidator.start      = jasmine.createSpy('-transitionValidator.start spy-')
        FakePusher.subscribe           = jasmine.createSpy('-Pusher.subscribe spy-')

        $httpBackend.expectPOST('/call_center/api/call_station.json').respond(callStation)
        tplUrls = [
          '/scripts/dialer/dialer.tpl.html',
          '/callveyor/dialer/ready/callFlowButtons.tpl.html',
          '/callveyor/dialer/ready/callInPhone.tpl.html',
          '/callveyor/dialer/ready/callStatus.tpl.html',
          '/callveyor/dialer/hold/callFlowButtons.tpl.html',
          '/callveyor/dialer/hold/callStatus.tpl.html'
        ]
        for url in tplUrls
          $httpBackend.whenGET(url).respond('<div ui-view>
                                              <div ui-view="callFlowButtons"></div>
                                              <div ui-view="callInPhone"></div>
                                              <div ui-view="callStatus"></div>
                                            </div>')

        $controller('DialerCtrl', {$scope, callStation})
    ))

    afterEach ->
      $httpBackend.verifyNoOutstandingRequest()

    it 'puts resolved callStation.caller into "caller" prop of "callStation" cache', ->
      cache = $cacheFactory.get('CallStation')
      expect(cache.get('caller')).toEqual(callStation.caller)

    it 'puts callStation.campaign into "campaign" prop of "callStation" cache', ->
      cache = $cacheFactory.get('CallStation')
      expect(cache.get('campaign')).toEqual(callStation.campaign)

    it 'puts callStation.call_station into "call_station" prop of "callStation" cache', ->
      cache = $cacheFactory.get('CallStation')
      expect(cache.get('call_station')).toEqual(callStation.call_station)

    it "subscribes appropriate idCallFlow handler to corresponding event on the callStation.caller.session_key channel", ->
      for event in pusherEvents
        expect(FakePusher.subscribe).toHaveBeenCalledWith(callStation.caller.session_key, event, idCallFlow[camelCase(event)])

    it 'starts the transitionValidator', ->
      expect(transitionValidator.start).toHaveBeenCalled()

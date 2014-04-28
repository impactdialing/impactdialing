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
    data: {
      caller: {
        session_key: 'caller-session-key'
      }
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
        idCallFlow.survey.save.success = jasmine.createSpy('-survey:save:success spy-')
        FakePusher.subscribe           = jasmine.createSpy('-Pusher.subscribe spy-')

        $httpBackend.whenPOST('/call_center/api/call_station.json').respond(callStation)
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

    it 'puts resolved callStation.data into "data" of "callStation" cache', ->
      cache = $cacheFactory.get('callStation')
      expect(cache.get('data')).toEqual(callStation.data)

    it 'binds idCallFlow.survey.save.success to "survey:save:success"', ->
      $rootScope.$broadcast('survey:save:success')
      expect(idCallFlow.survey.save.success).toHaveBeenCalled()

    it "subscribes appropriate idCallFlow handler to corresponding event on the callStation.data.caller.session_key channel", ->
      for event in pusherEvents
        expect(FakePusher.subscribe).toHaveBeenCalledWith(callStation.data.caller.session_key, event, idCallFlow[camelCase(event)])

    it 'starts the transitionValidator', ->
      expect(transitionValidator.start).toHaveBeenCalled()

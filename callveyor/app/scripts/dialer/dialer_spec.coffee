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
                'transfer_conference_ended', 'warm_transfer', 'cold_transfer', 'caller_kicked_off']

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

  describe 'constants', ->
    validTransitions = {}

    beforeEach(inject((_validTransitions_) ->
      validTransitions = _validTransitions_
    ))

    it '"validTransitions" contains a mapping of allowed transitions', ->
      expect(validTransitions.toString()).toBe('[object Object]')

  describe 'DialerCtrl', ->
    $rootScope    = ''
    $scope        = $rootScope
    $state        = ''
    $cacheFactory = ''
    $httpBackend  = ''
    $controller   = ''
    Pusher        = ''
    idCallFlow    = ''

    beforeEach(inject(
      (_$rootScope_, _$state_, _$cacheFactory_, _$httpBackend_, _$controller_, _Pusher_, _idCallFlow_) ->
        $rootScope                     = _$rootScope_
        $scope                         = $rootScope
        $state                         = _$state_
        $cacheFactory                  = _$cacheFactory_
        $httpBackend                   = _$httpBackend_
        $controller                    = _$controller_
        idCallFlow                     = _idCallFlow_
        idCallFlow.survey.save.success = jasmine.createSpy('-survey:save:success spy-')
        FakePusher.subscribe           = jasmine.createSpy('-Pusher.subscribe spy-')
        Pusher                         = _Pusher_

        $controller('DialerCtrl', {$scope, callStation})
    ))

    it 'puts resolved callStation.data into "data" of "callStation" cache', ->
      cache = $cacheFactory.get('callStation')
      expect(cache.get('data')).toEqual(callStation.data)

    it 'binds idCallFlow.survey.save.success to "survey:save:success"', ->
      $rootScope.$broadcast('survey:save:success')
      expect(idCallFlow.survey.save.success).toHaveBeenCalled()

    for event in pusherEvents
      it "subscribes idCallFlow.#{camelCase(event)} handler to #{event} on the callStation.data.caller.session_key channel", ->
        expect(Pusher.subscribe).toHaveBeenCalledWith(callStation.data.caller.session_key, event, idCallFlow[camelCase(event)])

  describe '$state transition sanity checks', ->
    $state       = ''
    $httpBackend = ''
    $rootScope   = ''
    beforeEach(inject(
      (_$rootScope_, _$state_, _$httpBackend_) ->
        $state = _$state_
        $httpBackend = _$httpBackend_
        $rootScope = _$rootScope_
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
          $httpBackend.whenGET(url).respond('<p>Hello</p>')
    ))

    describe 'fromState is dialer.ready', ->
      beforeEach ->
        console.log 'PRE $state.current', $state.current, $state.transition
        s = (r) -> console.log 'dialer.ready transition done', r
        p = $state.transitionTo('dialer.ready')
        # $state.transition.then(s,s).catch(s).finally(s)
        $rootScope.$apply()
        console.log '$state.current', $state.current, $state.transition
        expect($state.is('dialer.ready')).toBeTruthy()

      it 'allows transition to dialer.hold', ->
        s = (r) -> console.log 'dialer.hold transition done', r
        p = $state.go('dialer.hold')
        p.then(s,s)
        $rootScope.$apply()
        expect($state.is('dialer.hold')).toBeTruthy()

      it 'prevents other transitions'

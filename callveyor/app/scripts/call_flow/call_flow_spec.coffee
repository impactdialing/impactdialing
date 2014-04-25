describe 'callveyor.call_flow', ->
  $rootScope          = ''
  service             = ''
  $state              = ''
  $timeout            = ''
  $cacheFactory       = ''
  idFlashFactory      = ''
  idHttpDialerFactory = ''

  beforeEach module('callveyor.call_flow', ($stateProvider) ->
    # todo: figure out wtf this (and variant) works
    # variant:
    ###
    $stateProvider.state('dialer', {})
    $stateProvider.state('dialer.hold', {})
    ->
    ###
    # In short, the fn passed to ng-mocks `module` must return a fn.
    # Which is counter to all examples everywhere.
    ->
      $stateProvider.state('dialer', {})
      $stateProvider.state('dialer.ready', {})
      $stateProvider.state('dialer.hold', {})
      $stateProvider.state('dialer.stop', {})
      $stateProvider.state('dialer.active', {})
      $stateProvider.state('dialer.wrap', {})
  )

  beforeEach(inject((_$rootScope_, _$state_, _$timeout_, _$cacheFactory_, _idCallFlow_, _idFlashFactory_, _idHttpDialerFactory_) ->
    $rootScope = _$rootScope_
    $state   = _$state_
    $timeout = _$timeout_
    $cacheFactory = _$cacheFactory_
    service  = _idCallFlow_
    idFlashFactory = _idFlashFactory_
    idHttpDialerFactory = _idHttpDialerFactory_
  ))

  describe 'handlers', ->
    beforeEach ->
      idFlashFactory.now = jasmine.createSpy('-idFlashFactory.now spy-')

    it 'initializes a "call" cache', ->
      cache = $cacheFactory.get('call')
      expect(cache).toBeDefined()

    describe 'survey.save.success', ->
      it 'transitions to dialer.hold', ->
        service.survey.save.success()
        $timeout(-> expect($state.is('dialer.hold')).toBeTruthy())

    describe 'startCalling(data)', ->
      it 'updates the callStation.caller.session_id cache w/ data.caller_session_id', ->
        data = {caller_session_id: 42}
        callStation = {caller: {}}
        callStationCache = $cacheFactory('callStation')
        callStationCache.put('data', callStation)
        service.startCalling(data)
        cache = $cacheFactory.get('callStation')
        station = cache.get('data')
        expect(station.caller.session_id).toEqual(data.caller_session_id)

    describe 'conferenceStarted(contact)', ->
      callStationCache = ''
      contactCache     = ''
      contact = {}
      campaign = {type: 'blah'}

      beforeEach ->
        callStationCache = $cacheFactory('callStation')
        contactCache     = $cacheFactory('contact')

      describe 'when the campaign is out of leads', ->
        beforeEach ->
          contact = {campaign_out_of_leads: true}

        it 'displays a warning message to the user which self-destructs in some seconds', ->
          service.conferenceStarted(contact)
          expect(idFlashFactory.now).toHaveBeenCalledWith('warning', jasmine.any(String), jasmine.any(Number))

        it 'transitions to dialer.stop', ->
          service.conferenceStarted(contact)
          $timeout(-> expect($state.is('dialer.hold')).toBeTruthy())

      describe 'when the campaign is not out of leads', ->
        beforeEach ->
          station = {campaign}
          callStationCache.put("data", station)
          contact = {fields: {id: 12, first_name: 'John', last_name: 'Apple'}}

        it 'stores contact as "data" in the "contact" cache', ->
          service.conferenceStarted(contact)
          cache = $cacheFactory.get('contact')
          data = cache.get('data')
          expect(data).toEqual(contact)

        it 'broadcasts "contact:changed on $rootScope', ->
          contactChange = jasmine.createSpy('-contact:changed event spy-')
          $rootScope.$on('contact:changed', contactChange)
          service.conferenceStarted(contact)
          expect(contactChange).toHaveBeenCalled()

        it 'transitions to dialer.hold', ->
          service.conferenceStarted(contact)
          $timeout(-> expect($state.is('dialer.hold')).toBeTruthy())

        describe 'in Power mode', ->
          caller = ''

          beforeEach ->
            idHttpDialerFactory.dial = jasmine.createSpy('-idHttpDialerFactory.dial spy-')
            campaign.type = 'Power'
            caller = {
              id: 12,
              session_id: 42
            }
            station = {campaign, caller}
            callStationCache.put("data", station)

          it 'dials the contact', ->
            service.conferenceStarted(contact)
            expect(idHttpDialerFactory.dial).toHaveBeenCalledWith(caller.id, {
              session_id: caller.session_id,
              voter_id: contact.fields.id
            })

    describe 'callerConnectedDialer', ->
      it 'removes "data" from "contact" cache', ->
        cache = $cacheFactory('contact')
        contact = {fields: {id: 42}}
        cache.put('data', contact)
        service.callerConnectedDialer()
        expect(cache.get('data')).not.toBeDefined()

    describe 'callerReassigned(contact)', ->
      it 'resets everything... by ...?'

    describe 'callingVoter', ->
      it 'may be useless'

    describe 'voterConnected(data)', ->
      callCache = ''
      data = {call_id: 41}
      beforeEach ->
        callCache = $cacheFactory.get('call')

      it 'updates "id" on the "call" cache with data.call_id', ->
        service.voterConnected(data)
        expect(callCache.get('id')).toEqual(data.call_id)

      it 'transitions to dialer.active', ->
        service.voterConnected(data)
        $timeout(-> expect($state.is('dialer.active')).toBeTruthy())

    describe 'voterConnectedDialer(data)', ->
      contactCache = ''
      voter = {fields: {id: 40}}
      data = {call_id: 41, voter}

      beforeEach ->
        contactCache = $cacheFactory('contact')

      it 'updates "data" on "contact" cache with data.voter', ->
        service.voterConnectedDialer(data)
        cache = $cacheFactory.get('contact')
        expect(cache.get('data')).toEqual(data.voter)

      it 'updates "id" on "call" cache with data.call_id', ->
        service.voterConnectedDialer(data)
        cache = $cacheFactory.get('call')
        expect(cache.get('id')).toEqual(data.call_id)

      it 'transitions to dialer.active', ->
        service.voterConnectedDialer(data)
        $timeout(-> expect($state.is('dialer.active')).toBeTruthy())

    describe 'voterDisconnected', ->
      it 'transitions to dialer.wrap', ->
        service.voterDisconnected()
        $timeout(-> expect($state.is('dialer.wrap')).toBeTruthy())

    describe 'callerDisconnected', ->
      describe 'when $state is dialer.active', ->
        beforeEach ->
          # must run expectations in $timeout to ensure transition has completed
          $state.go('dialer.active')

        it 'displays a warning to the user', ->
          $timeout ->
            service.callerDisconnected()
            expect(idFlashFactory.now).toHaveBeenCalledWith('warning', jasmine.any(String))

        it 'transitions to dialer.wrap', ->
          $timeout ->
            service.callerDisconnected()
            $timeout(-> expect($state.is('dialer.wrap')).toBeTruthy())

      describe 'when $state is NOT dialer.active', ->
        it 'transitions to dialer.ready', ->
          expect($state.is('dialer.active')).toBeFalsy()
          service.callerDisconnected()
          $timeout(-> expect($state.is('dialer.ready')).toBeTruthy())

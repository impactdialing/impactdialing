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

    # todo: move test state defs to helper
    ->
      $stateProvider.state('abort', {})
      $stateProvider.state('dialer', {})
      $stateProvider.state('dialer.ready', {})
      $stateProvider.state('dialer.hold', {})
      $stateProvider.state('dialer.stop', {})
      $stateProvider.state('dialer.active', {})
      $stateProvider.state('dialer.active.transfer', {})
      $stateProvider.state('dialer.active.transfer.conference', {})
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
      idFlashFactory.nowAndDismiss = jasmine.createSpy('-idFlashFactory.nowAndDismiss spy-')

    it 'initializes a "call" cache', ->
      cache = $cacheFactory.get('Call')
      expect(cache).toBeDefined()

    describe 'survey.save.success', ->
      it 'may not do anything'

    describe 'startCalling(data)', ->
      it 'updates the CallStationCache.caller.session_id w/ data.caller_session_id', ->
        data = {caller_session_id: 42}

        callStationCache = $cacheFactory.get('CallStation')
        callStationCache.put('caller', {})
        service.startCalling(data)
        cache = $cacheFactory.get('CallStation')
        actual = cache.get('caller')
        expect(actual.session_id).toEqual(data.caller_session_id)

    describe 'conferenceStarted(contact)', ->
      callStationCache = ''
      contactCache     = ''
      campaign = {type: 'blah'}
      contact = {dialer: campaign.type}

      beforeEach ->
        callStationCache = $cacheFactory.get('CallStation')
        contactCache     = $cacheFactory.get('Contact')
        callStationCache.put('campaign', campaign)

      describe 'when the campaign is out of leads', ->
        beforeEach ->
          contact = {
            campaign_out_of_leads: true
            dialer: campaign.type
          }

        it 'caches a warning message to the user to be displayed after $state transition completes', ->
          service.conferenceStarted(contact)
          actual = $cacheFactory.get('Flash')
          expect(actual.get('error')).toContain("All contacts have been dialed!")

        it 'transitions to abort', ->
          service.conferenceStarted(contact)
          $rootScope.$apply()
          expect($state.is('abort')).toBeTruthy()

      describe 'when the campaign is not out of leads', ->
        beforeEach ->
          station = {campaign}
          callStationCache.put("campaign", campaign)
          contact = {
            fields: {id: 12, first_name: 'John', last_name: 'Apple'}
            dialer: campaign.type
          }

        it 'stores contact as "data" in the "contact" cache', ->
          service.conferenceStarted(contact)
          cache = $cacheFactory.get('Contact')
          data = cache.get('data')
          expect(data).toEqual(contact)

        it 'broadcasts "contact:changed on $rootScope', ->
          contactChange = jasmine.createSpy('-contact:changed event spy-')
          $rootScope.$on('contact:changed', contactChange)
          service.conferenceStarted(contact)
          expect(contactChange).toHaveBeenCalled()

        it 'transitions to dialer.hold', ->
          service.conferenceStarted(contact)
          $rootScope.$apply()
          expect($state.is('dialer.hold')).toBeTruthy()

        describe 'in Power mode', ->
          caller = ''

          beforeEach ->
            idHttpDialerFactory.dialContact = jasmine.createSpy('-idHttpDialerFactory.dialContact spy-')
            campaign.type = 'Power'
            caller = {
              id: 12,
              session_id: 42
            }
            angular.extend(contact, {dialer: campaign.type})

            callStationCache.put("campaign", campaign)
            callStationCache.put("caller", caller)

          it 'dials the contact', ->
            service.conferenceStarted(contact)
            expect(idHttpDialerFactory.dialContact).toHaveBeenCalledWith(caller.id, {
              session_id: caller.session_id,
              voter_id: contact.fields.id
            })

    describe 'callerConnectedDialer', ->
      it 'transitions to dialer.hold', ->
        service.callerConnectedDialer()
        $rootScope.$apply()
        expect($state.is('dialer.hold')).toBeTruthy()

      it 'removes "data" from "contact" cache', ->
        cache = $cacheFactory.get('Contact')
        contact = {fields: {id: 42}}
        cache.put('data', contact)
        service.callerConnectedDialer()
        $rootScope.$apply()
        expect(cache.get('data')).toEqual({})

    describe 'callerReassigned(contact)', ->
      it 'resets everything... by ...?'

    describe 'callingVoter', ->
      it 'may be useless'

    describe 'voterConnected(data)', ->
      callCache = ''
      data = {call_id: 41}
      beforeEach ->
        callCache = $cacheFactory.get('Call')

      it 'updates "id" on the "call" cache with data.call_id', ->
        service.voterConnected(data)
        $rootScope.$apply()
        expect(callCache.get('id')).toEqual(data.call_id)

      it 'transitions to dialer.active', ->
        service.voterConnected(data)
        $rootScope.$apply()
        expect($state.is('dialer.active')).toBeTruthy()

    describe 'voterConnectedDialer(data)', ->
      contactCache = ''
      voter = {fields: {id: 40}}
      data = {call_id: 41, voter}

      beforeEach ->
        contactCache = $cacheFactory.get('Contact')

      it 'updates "data" on "contact" cache with data.voter', ->
        service.voterConnectedDialer(data)
        $rootScope.$apply()
        cache = $cacheFactory.get('Contact')
        expect(cache.get('data')).toEqual(data.voter)

      it 'updates "id" on "call" cache with data.call_id', ->
        service.voterConnectedDialer(data)
        $rootScope.$apply()
        cache = $cacheFactory.get('Call')
        expect(cache.get('id')).toEqual(data.call_id)

      it 'transitions to dialer.active', ->
        service.voterConnectedDialer(data)
        $rootScope.$apply()
        expect($state.is('dialer.active')).toBeTruthy()

    describe 'voterDisconnected', ->
      it 'transitions to dialer.wrap', ->
        service.voterDisconnected()
        $rootScope.$apply()
        expect($state.is('dialer.wrap')).toBeTruthy()

    describe 'callerDisconnected', ->
      describe 'when $state is dialer.active', ->
        beforeEach ->
          $state.go('dialer.active')
          $rootScope.$apply()

        it 'displays a warning to the user', ->
          service.callerDisconnected()
          self.expect(idFlashFactory.now).toHaveBeenCalledWith('warning', jasmine.any(String))

        it 'transitions to dialer.wrap', ->
          service.callerDisconnected()
          $rootScope.$apply()
          expect($state.is('dialer.wrap')).toBeTruthy()

      describe 'when $state is NOT dialer.active', ->
        it 'transitions to dialer.ready', ->
          expect($state.is('dialer.active')).toBeFalsy()
          service.callerDisconnected()
          $rootScope.$apply()
          expect($state.is('dialer.ready')).toBeTruthy()

    describe 'transferBusy', ->
      it 'displays a notice to the user'

    describe 'transferConnected(data)', ->
      transferCache = ''
      data = {call_id: 42, type: 'blah'}

      beforeEach ->
        transferCache = $cacheFactory.get('Transfer')

      it 'stores "type" on "transfer" cache with data.type', ->
        service.transferConnected(data)
        cache = $cacheFactory.get('Transfer')
        expect(cache.get('type')).toEqual(data.type)

      it 'displays a notice to the user, reporting the transfer is about to connect that self-destructs in some seconds'
      # , ->
      #   service.transferConnected(data)
      #   expect(idFlashFactory.now).toHaveBeenCalledWith('notice', jasmine.any(String), jasmine.any(Number))

    describe 'contactJoinedTransferConference (contact just joined conference)', ->
      describe 'when cold transfer', ->
        transferCache = {}

        beforeEach ->
          transferCache = $cacheFactory.get('Transfer')
          transferCache.put('type', 'cold')

        it 'transitions to dialer.wrap', ->
          service.contactJoinedTransferConference()
          $rootScope.$apply()
          expect($state.is('dialer.wrap')).toBeTruthy()

    describe 'callerJoinedTransferConference (caller just joined conference)', ->
      it 'transitions to dialer.active.transfer.conference', ->
        service.callerJoinedTransferConference()
        $rootScope.$apply()
        expect($state.is('dialer.active.transfer.conference')).toBeTruthy()

    describe 'transferConferenceEnded', ->
      transferCache = {}
      transfer = {id: 32}

      describe 'warm transfer', ->
        beforeEach ->
          transfer.transfer_type = 'warm'
          transferCache = $cacheFactory.get('Transfer')
          transferCache.put('type', 'warm')
          transferCache.put('selected', transfer)

        it 'removes type property from TransferCache', ->
          service.transferConferenceEnded()
          typeCache = transferCache.get('type')
          expect(typeCache).toBeUndefined()

        it 'removes selected property from TransferCache', ->
          service.transferConferenceEnded()
          selectCache = transferCache.get('selected')
          expect(selectCache).toBeUndefined()

        describe 'current state is dialer.active.transfer.conference', ->
          beforeEach ->
            $state.go('dialer.active.transfer.conference')
            $rootScope.$apply()

          it 'displays a notice to the user, reporting the transfer party has left that self-destructs in some seconds'
          # , ->
          #   service.transferConferenceEnded()
          #   expect(idFlashFactory.now).toHaveBeenCalledWith('notice', jasmine.any(String), jasmine.any(Number))

          it 'transitions to dialer.active', ->
            service.transferConferenceEnded()
            $rootScope.$apply()
            expect($state.is('dialer.active')).toBeTruthy()

        describe 'current state is dialer.wrap', ->
          beforeEach ->
            $state.go('dialer.wrap')
            $rootScope.$apply()

          it 'displays a notice to the user, reporting that both the transfer party and voter have left the conference and that self-destructs in some seconds'
          # , ->
          #   service.transferConferenceEnded()
          #   $rootScope.$apply()
          #   expect(idFlashFactory.now).toHaveBeenCalledWith('notice', jasmine.any(String), jasmine.any(Number))

      describe 'cold transfer', ->
        beforeEach ->
          transfer.transfer_type = 'cold'
          transferCache = $cacheFactory.get('Transfer')
          transferCache.put('type', 'cold')


        it 'removes type property from TransferCache', ->
          service.transferConferenceEnded()
          typeCache = transferCache.get('type')
          expect(typeCache).toBeUndefined()

        it 'removes selected property from TransferCache', ->
          service.transferConferenceEnded()
          selectCache = transferCache.get('selected')
          expect(selectCache).toBeUndefined()

        it 'does nothing else', ->
          for event in ['dialer.active.transfer.conference', 'dialer.wrap']
            $state.go(event)
            $rootScope.$apply()
            stateChangeSpy = jasmine.createSpy('-$state change spy-')
            bound = $rootScope.$on('$stateChangeStart', stateChangeSpy)
            service.transferConferenceEnded()
            $rootScope.$apply()
            expect(stateChangeSpy).not.toHaveBeenCalled()
            bound()

    describe 'callerKickedOff', ->
      it 'transitions to dialer.wrap', ->
        service.callerKickedOff()
        $rootScope.$apply()
        expect($state.is('dialer.wrap')).toBeTruthy()

    describe 'callEnded(data)', ->
      sharedScope = {}
      data = {
        status: 'no-answer'
        campaign_type: 'Power'
      }
      cache = ''

      beforeEach ->
        $state.is = (state) ->
          state == 'dialer.hold'
        sharedScope.reset = jasmine.createSpy('-hold cache sharedScope.reset spy-')
        cache = $cacheFactory('hold')
        cache.put('sharedScope', sharedScope)

      describe 'when data.status != completed and $state.is dialer.hold and data.campaign_type != Predictive', ->
        beforeEach ->
        it 'calls reset on "sharedScope" prop of "hold" cache', ->
          service.callEnded(data)
          expect(sharedScope.reset).toHaveBeenCalled()
        it 'displays info message to user', ->
          service.callEnded(data)
          expect(idFlashFactory.nowAndDismiss).toHaveBeenCalledWith('info', jasmine.any(String), jasmine.any(Number))

      describe 'when data.status == completed or $state is not dialer.hold or data.campaign_type == Predictive', ->
        it 'does nothing', ->
          data.status = 'completed'
          service.callEnded(data)
          expect(sharedScope.reset).not.toHaveBeenCalled()
          data.status = 'blah'
          data.campaign_type = 'Predictive'
          service.callEnded(data)
          expect(sharedScope.reset).not.toHaveBeenCalled()
          data.campaign_type = 'Preview'
          $state.is = -> false
          service.callEnded(data)
          expect(sharedScope.reset).not.toHaveBeenCalled()

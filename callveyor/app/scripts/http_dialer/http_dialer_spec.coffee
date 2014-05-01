describe 'callveyor.http_dialer', ->
  $injector        = ''
  $rootScope       = ''
  $httpBackend     = ''
  factory          = ''
  usSpinnerService = ''
  caller = {
    id: 3
  }
  params = {
    voter_id: 12
    session_id: 42
  }
  dialerUrl = "/call_center/api/#{caller.id}/call_voter"

  beforeEach module('callveyor.http_dialer')

  beforeEach ->
    inject((_$injector_, _$httpBackend_) ->
      $injector        = _$injector_
      $httpBackend     = _$httpBackend_
      $rootScope       = $injector.get('$rootScope')
      factory          = $injector.get('idHttpDialerFactory')
      usSpinnerService = $injector.get('usSpinnerService')
    )
    usSpinnerService.spin = jasmine.createSpy('-usSpinnerService.spin spy-')
    usSpinnerService.stop = jasmine.createSpy('-usSpinnerService.stop spy-')

  describe 'dial(caller_id, params, retry)', ->
    describe 'when called with invalid or undefined caller_id, params.session_id or params.voter_id', ->
      it 'throws an Error', ->
        expect(-> factory.dialContact(1, {session_id: 3})).toThrowError()
        expect(-> factory.dialContact(undefined, {session_id: 3, voter_id: 1})).toThrowError()
        expect(-> factory.dialContact(1, {voter_id: 1})).toThrowError()

    beforeEach ->
      $httpBackend.whenPOST(dialerUrl).respond({})
    it 'spins the global-spinner', ->
      factory.dialContact(caller.id, params)
      expect(usSpinnerService.spin).toHaveBeenCalled()

    it "POSTs given params to '#{dialerUrl}'", ->
      $httpBackend.expectPOST(dialerUrl).respond({})
      factory.dialContact(caller.id, params)
      $httpBackend.verifyNoOutstandingExpectation()

    describe 'POST is success', ->
      beforeEach ->
        $httpBackend.whenPOST(dialerUrl).respond(200)

      it 'broadcasts "http_dialer:success"', ->
        yay = jasmine.createSpy('-http_dialer:success event spy-')
        $rootScope.$on('http_dialer:success', yay)
        factory.dialContact(caller.id, params)
        $httpBackend.flush()
        expect(yay).toHaveBeenCalled()

    describe 'POST is a failure', ->
      describe 'retry is falsy', ->
        it 'broadcasts "http_dialer:error"', ->
          $httpBackend.expectPOST(dialerUrl).respond(408)
          boo = jasmine.createSpy('-http_dialer:error event spy-')
          $rootScope.$on('http_dialer:error', boo)
          factory.dialContact(caller.id, params)
          $httpBackend.flush()
          expect(boo).toHaveBeenCalled()

      describe 'retry is truthy', ->
        retrySpy = ''
        errorSpy = ''
        successSpy = ''

        describe 'AND HTTP response code is 408, 500 or 504', ->
          for statusCode in [408, 500, 504]
            beforeEach ->
              retrySpy = jasmine.createSpy('http_dialer:retry event spy-')
              errorSpy = jasmine.createSpy('http_dialer:error event spy-')
              successSpy = jasmine.createSpy('http_dialer:success event spy-')
              $rootScope.$on('http_dialer:retrying', retrySpy)
              $rootScope.$on('http_dialer:success', successSpy)
              $rootScope.$on('http_dialer:error', errorSpy)
              $httpBackend.expectPOST(dialerUrl).respond(statusCode)
              factory.dialContact(caller.id, params, true)
              $httpBackend.flush(1)

            it 'broadcasts "http_dialer:retrying"', ->
              expect(retrySpy).toHaveBeenCalled()

            it 'does not broadcast "http_dialer:error', ->
              expect(errorSpy).not.toHaveBeenCalled()

            it 'spins the global-spinner', ->
              expect(usSpinnerService.spin).toHaveBeenCalled()

            it 'retries only once in the face of a second failure', ->
              # intercept the retried request before the initial whenPOST stub can respond w/ 200
              $httpBackend.whenPOST(dialerUrl).respond(statusCode)
              $httpBackend.flush()
              $httpBackend.verifyNoOutstandingExpectation()
              expect(retrySpy.calls.count()).toEqual(1)

            describe 'retry POST is success', ->
              beforeEach ->
                $httpBackend.flush()

              it 'broadcasts "http_dialer:success', ->
                expect(successSpy).toHaveBeenCalled()

            describe 'retry POST is a failure', ->
              it 'broadcasts "http_dialer:error"', ->
                $httpBackend.whenPOST(dialerUrl).respond(statusCode)
                $httpBackend.flush()
                $httpBackend.verifyNoOutstandingExpectation()
                expect(errorSpy).toHaveBeenCalled()

        describe 'BUT HTTP response code is other than 408, 500 or 504', ->
          it 'broadcasts "http_dialer:error"', ->
            errorSpy = jasmine.createSpy('-http_dialer:error event spy-')
            retrySpy = jasmine.createSpy('-http_dialer:retrying event spy-')
            $rootScope.$on('http_dialer:error', errorSpy)
            $rootScope.$on('http_dialer:retrying', retrySpy)
            $httpBackend.expectPOST(dialerUrl).respond(403, {error: "blah"})
            factory.dialContact(caller.id, params, true)
            $httpBackend.flush()
            $httpBackend.verifyNoOutstandingExpectation()
            expect(retrySpy).not.toHaveBeenCalled()
            expect(errorSpy).toHaveBeenCalled()


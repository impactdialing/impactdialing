describe 'pusherConnectionHandlers module', ->
  $injector = ''
  $rootScope = ''
  factory = ''
  idFlashFactory = ''
  usSpinnerService = ''
  pusher = {
    connection: {}
  }
  # http://pusher.com/docs/client_api_guide/client_connect#available-states
  pusherConnectionEvents = ['connecting_in', 'connecting', 'connected', 'failed', 'unavailable']

  # load the mod
  beforeEach module('pusherConnectionHandlers')

  # now the factory
  beforeEach ->
    inject((_$injector_) ->
      $injector = _$injector_
      $rootScope = $injector.get('$rootScope')
      factory = $injector.get('pusherConnectionHandlerFactory')
      idFlashFactory = $injector.get('idFlashFactory')
      usSpinnerService = $injector.get('usSpinnerService')
    )

  describe '.success(pusher)', ->
    for event in pusherConnectionEvents
      it "binds to '#{event}'", ->
        pusher.connection.bind = jasmine.createSpy('-pusher.connection.bind spy-')
        factory.success(pusher)
        expect(pusher.connection.bind).toHaveBeenCalledWith(event, jasmine.any(Function))

    describe 'connection handlers', ->
      trigger = ''
      beforeEach ->
        bound = {}
        pusher.connection.bind = (event, handler) -> bound[event] = handler
        pusher.connection.unbind = (event) -> delete bound[event]
        trigger = (event, delay) -> bound[event](delay)
        idFlashFactory.now = jasmine.createSpy('-idFlashFactory.now spy-')
        usSpinnerService.spin = jasmine.createSpy('-usSpinnerService.spin spy-')
        usSpinnerService.stop = jasmine.createSpy('-usSpinnerService.stop spy-')
        factory.success(pusher)

      describe 'connecting_in', ->
        it 'displays a warning to the user', ->
          trigger('connecting_in', 5)
          expect(idFlashFactory.now).toHaveBeenCalledWith('warning', jasmine.any(String))

      describe 'connecting', ->
        beforeEach -> trigger('connecting')

        describe 'when first fired', ->
          it 'displays a notice to the user', ->
            expect(idFlashFactory.now).toHaveBeenCalledWith('notice', jasmine.any(String))

          it 'resets the initial connecting handler to a reConnecting handler', ->
            idFlashFactory.now.calls.reset()
            trigger('connecting')
            # hack-ish test that will fail if reConnecting handler flashes 'notice' instead of 'warning'
            expect(idFlashFactory.now).not.toHaveBeenCalledWith('notice', jasmine.any(String))

          it 'spins the global-spinner', ->
            expect(usSpinnerService.spin).toHaveBeenCalledWith('global-spinner')

        describe 'when fired after the first time', ->
          beforeEach ->
            idFlashFactory.now.calls.reset()
            trigger('connecting')

          it 'displays a warning to the user', ->
            expect(idFlashFactory.now).toHaveBeenCalledWith('warning', jasmine.any(String))

      describe 'connected', ->
        pusherReadyHandler = ''
        beforeEach ->
          pusherReadyHandler = jasmine.createSpy('-broadcast pusher:ready event spy-')
          $rootScope.$on('pusher:ready', pusherReadyHandler)
          trigger('connected')

        describe 'when first fired', ->
          it 'stops the global-spinner', ->
            expect(usSpinnerService.stop).toHaveBeenCalledWith('global-spinner')

          it 'does not display any message to user', ->
            expect(idFlashFactory.now).not.toHaveBeenCalled()

          it 'resets the initial connected handler to a runTimeConnectedHandler', ->
            trigger('connected')
            expect(idFlashFactory.now).toHaveBeenCalledWith('success', jasmine.any(String), jasmine.any(Number))

          it 'broadcasts "pusher:ready" event on $rootScope', ->
            expect(pusherReadyHandler).toHaveBeenCalled()

        describe 'when fired after the first time', ->
          beforeEach -> trigger('connected')
          it 'stops the global-spinner', ->
            expect(usSpinnerService.stop).toHaveBeenCalled()

          it 'displays a success message to the user, which auto-destructs after some seconds', ->
            expect(idFlashFactory.now).toHaveBeenCalledWith('success', jasmine.any(String), jasmine.any(Number))

      # failed event means the browser is not supported & neither flash nor http fallbacks are available
      describe 'failed', ->
        pusherBadBrowserHandler = ''
        beforeEach ->
          pusherBadBrowserHandler = jasmine.createSpy('-broadcast pusher:bad_browser event spy-')
          $rootScope.$on('pusher:bad_browser', pusherBadBrowserHandler)
          trigger('failed')

        it 'broadcasts "pusher:bad_browser" event on $rootScope', ->
          expect(pusherBadBrowserHandler).toHaveBeenCalled()

      # unavailable means pusher will retry in ~30 seconds
      describe 'unavailable', ->
        beforeEach -> trigger('unavailable')

        it 'displays a warning to the user', ->
          expect(idFlashFactory.now).toHaveBeenCalledWith('warning', jasmine.any(String))

'use strict'

idTransition = angular.module('idTransition', [
  'idDebug',
  'angularSpinner'
])
idTransition.factory('idTransitionPrevented', [
  '$rootScope', '$state', 'idDebugCache', 'usSpinnerService',
  ($rootScope,   $state,   idDebugCache,   usSpinnerService) ->
    isFailedResolve = (err) ->
      err.config? and err.config.url? and /(GET|POST)/.test(err.config.method)

    fn = (errObj) ->
      console.log 'report this problem', errObj
      $rootScope.transitionInProgress = false
      usSpinnerService.stop('global-spinner')

      if isFailedResolve(errObj)
        idDebugCache.put('abort', {error: errObj.data.message, errorObject: errObj})
        $state.go('abort')

    fn
])

idDebug = angular.module('idDebug', [])
idDebug.factory('idDebugCache', [
  '$cacheFactory',
  ($cacheFactory) ->
    cache = $cacheFactory('idDebugCache')
    data = {}
    window.idDebugData = data

    time = -> (new Date()).getTime()

    debugCache = {
      put: (key, value) ->
        t = time()
        data[t] = {}
        data[t][key] = value
        cache.put(key, value)
      get: (key) ->
        cache.get(key)
      remove: (key) ->
        cache.remove(key)
    }

    debugCache
])

callveyor = angular.module('callveyor', [
  'config',
  'ui.bootstrap',
  'ui.router',
  'doowb.angular-pusher',
  'pusherConnectionHandlers',
  'idTwilio',
  'idFlash',
  'idTransition',
  'idDebug',
  'angularSpinner',
  'callveyor.dialer'
])

callveyor.constant 'currentYear', (new Date()).getFullYear()

callveyor.config([
  '$stateProvider', 'serviceTokens', 'idTwilioServiceProvider', 'PusherServiceProvider',
  ($stateProvider,   serviceTokens,   idTwilioServiceProvider,   PusherServiceProvider) ->
    idTwilioServiceProvider.setScriptUrl('//static.twilio.com/libs/twiliojs/1.1/twilio.js')
    PusherServiceProvider.setPusherUrl('//d3dy5gmtp8yhk7.cloudfront.net/2.1/pusher.min.js')
    PusherServiceProvider.setToken(serviceTokens.pusher)


    $stateProvider.state('abort', {
      template: ''
      controller: 'AppCtrl.abort'
    })
])

callveyor.controller('AppCtrl.abort', [
  '$http', '$cacheFactory', 'idDebugCache', 'PusherService', 'idFlashFactory',
  ($http,   $cacheFactory,   idDebugCache,   PusherService,   idFlashFactory) ->
    console.log 'idDebugCache', idDebugCache
    abort = idDebugCache.get('abort')

    idFlashFactory.now('error', abort.error)

    twilioCache = $cacheFactory.get('Twilio')
    connection = twilioCache.get('connection')
    # whenDisconnected = ->
    # connection.disconnect(whenDisconnected)
    connection.disconnect()

    PusherService.then((p) ->
      console.log 'PusherService abort', p
    )
])

callveyor.controller('MetaCtrl', [
  '$scope', 'currentYear',
  ($scope, currentYear) ->
    # todo: de-register the $watch on $scope.meta.currentYear
    $scope.meta ||= {}
    $scope.meta.currentYear = currentYear
])

callveyor.controller('AppCtrl', [
  '$rootScope', '$scope', '$state', '$cacheFactory', 'usSpinnerService', 'PusherService', 'pusherConnectionHandlerFactory', 'idFlashFactory', 'idTransitionPrevented',
  ($rootScope,   $scope,   $state,   $cacheFactory,   usSpinnerService,   PusherService,   pusherConnectionHandlerFactory,   idFlashFactory,   idTransitionPrevented) ->
    idFlashFactory.scope = $scope
    $scope.flash = idFlashFactory

    # handle generic state change conditions
    transitionStart = ->
      usSpinnerService.spin('global-spinner')
      $rootScope.transitionInProgress = true
    transitionComplete = ->
      $rootScope.transitionInProgress = false
      usSpinnerService.stop('global-spinner')
    transitionError = (e) ->
      # todo: submit error to error collection tool
      console.error 'Error transitioning $state', e, $state.current
      # hmm: $stateChangeError seems to not be thrown when preventDefault is called
      # if e.message == 'transition prevented'
      #   # something called .preventDefault, probably the transitionGateway
      #   console.log 'todo: report transition prevented error to collection tool'
      transitionComplete()

    $rootScope.$on('$stateChangeStart', transitionStart)
    $rootScope.$on('$stateChangeSuccess', transitionComplete)
    $rootScope.$on('$stateChangeError', transitionError)

    # handle pusher app-specific events
    markPusherReady = ->
      p = $state.go('dialer.ready')
      p.catch(idTransitionPrevented)
    abortAllAndNotifyUser = ->
      # todo: implement
      console.log 'Unsupported browser...'

    $rootScope.$on('pusher:ready', markPusherReady)
    $rootScope.$on('pusher:bad_browser', abortAllAndNotifyUser)

    PusherService.then(pusherConnectionHandlerFactory.success,
                       pusherConnectionHandlerFactory.loadError)
])

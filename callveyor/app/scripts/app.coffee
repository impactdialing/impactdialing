'use strict'

idTransition = angular.module('idTransition', [
  'idCacheFactories',
  'angularSpinner'
])
idTransition.factory('idTransitionPrevented', [
  '$rootScope', '$state', 'ErrorCache', 'FlashCache', 'usSpinnerService',
  ($rootScope,   $state,   ErrorCache,   FlashCache,   usSpinnerService) ->
    isFailedResolve = (err) ->
      err.config? and err.config.url? and /(GET|POST)/.test(err.config.method)

    fn = (errObj) ->
      console.log 'Transition Prevented.', errObj
      $rootScope.transitionInProgress = false
      usSpinnerService.stop('global-spinner')

      if isFailedResolve(errObj)
        # record the time & error
        key = (new Date()).getTime()
        val = {error: errObj, context: 'Remote $state dependency failed to resolve.'}
        ErrorCache.put(key, val)

        FlashCache.put('error', errObj.data.message)
        $state.go('abort')

    fn
])

angular.module('exceptionOverride', []).factory('$exceptionHandler', [
  '$window', 'CallStationCache', 'appMeta',
  ($window,   CallStationCache,   appMeta) ->
    Bugsnag.notifyReleaseStages = ['development', 'production']
    Bugsnag.releaseStage        = appMeta.stage
    Bugsnag.appVersion          = appMeta.version
    (exception, cause) ->
      caller           = CallStationCache.get('caller')
      campaign         = CallStationCache.get('campaign')
      station          = CallStationCache.get('call_station')
      Bugsnag.user     = caller
      Bugsnag.metaData = {
        campaign
        station
      }
      Bugsnag.notifyException(exception, {
        angular: {
          cause: cause
        }
      })
])

angular.module('HttpErrors', []).factory('idHttpError', [
  '$window', '$state', 'FlashCache', 'CallStationCache',
  ($window,   $state,   FlashCache,   CallStationCache) ->
    httpError = (resp) ->
      if resp.status? and /^5\d\d/.test(resp.status)
        err = new Error("Survey fields failed to load")
        Bugsnag.notifyException(err, {
          campaign: CallStationCache.get('campaign')
          station: CallStationCache.get('call_station')
          user: CallStationCache.get('caller')
          http_response: {
            status: resp.status,
            status_text: resp.statusText,
            data: resp.data
          },
          angular: {
            cause: cause
            state: $state.current
          }
        })
      else if resp.message?
        console.log 'Error', resp.message
        FlashCache.put('error', resp.message)
        $state.go('abort')

    httpError
])

callveyor = angular.module('callveyor', [
  'config',
  'exceptionOverride',
  'idDeviceDetect',
  'ui.bootstrap',
  'ui.router',
  'doowb.angular-pusher',
  'pusherConnectionHandlers',
  'idTwilio',
  'idFlash',
  'idTransition',
  'idCacheFactories',
  'angularSpinner',
  'callveyor.dialer'
])

callveyor.config([
  '$stateProvider', 'serviceTokens', 'idTwilioServiceProvider', 'PusherServiceProvider',
  ($stateProvider,   serviceTokens,   idTwilioServiceProvider,   PusherServiceProvider) ->
    idTwilioServiceProvider.setScriptUrl('//static.twilio.com/libs/twiliojs/1.2/twilio.js')
    # for testing twilio.js error conditions, use the below self-hosted file that can be edited to trigger errors
    # idTwilioServiceProvider.setScriptUrl('http://localhost:5000/twiliojs/1.2/twilio.js')

    if window.location.hostname == 'au.impactdialing.com'
      PusherServiceProvider.setOptions({cluster: 'ap1'})
      PusherServiceProvider.setToken(serviceTokens.pusherAsia)
    else
      PusherServiceProvider.setToken(serviceTokens.pusher)

    $stateProvider.state('abort', {
      template: ''
      controller: 'AppCtrl.abort'
    })
])

callveyor.controller('AppCtrl.abort', [
  '$http', 'TwilioCache', 'FlashCache', 'PusherService', 'idFlashFactory',
  ($http,   TwilioCache,   FlashCache,   PusherService,   idFlashFactory) ->
    # console.log 'AppCtrl.abort', FlashCache.get('error'), FlashCache.info()
    flash = FlashCache.get('error')
    idFlashFactory.now('danger', flash)
    FlashCache.remove('error')
    console.log 'AppCtrl.abort', flash

    twilioConnection = TwilioCache.get('connection')

    if twilioConnection?
      twilioConnection.disconnect()

    PusherService.then((pusher) ->
      if pusher.connection.state == 'connected'
        pusher.disconnect()
    )
])

callveyor.controller('MetaCtrl', [
  '$scope',
  ($scope) ->
    # todo: de-register the $watch on $scope.meta.currentYear
    $scope.currentYear = (new Date()).getFullYear()
])

callveyor.controller('AppCtrl', [
  '$rootScope', '$scope', '$state', '$timeout', '$window', 'usSpinnerService', 'PusherService', 'pusherConnectionHandlerFactory', 'idFlashFactory', 'idTransitionPrevented', 'TransitionCache', 'HouseholdCache', 'CallStationCache', 'ErrorCache',
  ($rootScope,   $scope,   $state,   $timeout,   $window,   usSpinnerService,   PusherService,   pusherConnectionHandlerFactory,   idFlashFactory,   idTransitionPrevented,   TransitionCache,   HouseholdCache,   CallStationCache,   ErrorCache) ->
    $rootScope.transitionInProgress = false
    getPhone = ->
      household = HouseholdCache.get('data')
      phone   = ''
      if household? and household.phone?
        phone = household.phone
      phone
    getMeta = ->
      caller = CallStationCache.get('caller')
      campaign = CallStationCache.get('campaign')
      {caller, campaign}
    # handle generic state change conditions
    transitionStart = (event, toState, toParams, fromState, fromParams) ->
      usSpinnerService.spin('global-spinner')
      $rootScope.transitionInProgress = true
    transitionComplete = (event, toState, toParams, fromState, fromParams) ->
      $rootScope.transitionInProgress = false
      usSpinnerService.stop('global-spinner')
      Bugsnag.context = toState.name
    transitionError = (event, unfoundState, fromState, fromParams) ->
      phone = getPhone()
      meta  = getMeta()

      err = new Error("$state change failed to transition")
      Bugsnag.notifyException(err, {
        angular: {
          cause: cause,
          to: unfoundState.name,
          from: fromState.name,
          error_cache: angular.toJson(ErrorCache, true),
          phone: phone,
          meta: angular.toJson(meta, true)
        }
      })

      # hmm: $stateChangeError seems to not be thrown when preventDefault is called
      # if e.message == 'transition prevented'
      #   # something called .preventDefault, probably the transitionGateway
      #   console.log 'todo: report transition prevented error to collection tool'
      $rootScope.transitionInProgress = false
      usSpinnerService.stop('global-spinner')

    $rootScope.$on('$stateChangeStart', transitionStart)
    $rootScope.$on('$stateChangeSuccess', transitionComplete)
    $rootScope.$on('$stateChangeError', transitionError)

    # handle pusher app-specific events
    markPusherReady = ->
      now = ->
        p = $state.go('dialer.ready')
        p.catch(idTransitionPrevented)
      $timeout(now, 300)
    abortAllAndNotifyUser = ->
      # todo: implement
      console.log 'Unsupported browser...'
      TransitionCache.put('pusher:bad_browser', '.')

    $rootScope.$on('pusher:ready', markPusherReady)
    $rootScope.$on('pusher:bad_browser', abortAllAndNotifyUser)

    PusherService.then(pusherConnectionHandlerFactory.success,
                       pusherConnectionHandlerFactory.loadError)
])

'use strict'

twilio = angular.module('idTwilio', [
  'idScriptLoader',
  'config'
])

twilio.factory('idTwilioConfig', [
  '$http', '$window', 'TwilioCache', 'debug',
  ($http,   $window,   TwilioCache,   debug) ->
    token = ''

    factory = {
      token,
      fetchToken: (successCallback, errorCallback) ->
        p = $http.get(TwilioCache.get('tokenUrl'))
        s = (resp) ->
          factory.token = resp.data.twilio_token
          if successCallback?
            successCallback(resp)
        e = (err) ->
          $window._errs.push(err)
          if errorCallback?
            errorCallback(err)
        p.then(s, e)
      setupDevice: ->
        if $window.Twilio?
          new $window.Twilio.Device.setup(factory.token, {
            'debug': debug
          })
        else
          console.log 'setupDevice: Twilio not loaded.'
    }

    factory.debug = debug

    factory
])

twilio.provider('idTwilioService', ->
  _scriptUrl = '//static.twilio.com/libs/twiliojs/1.2/twilio.js'
  _scriptId = 'TwilioJS'
  _tokenUrl = '/call_center/api/twilio_token.json'
  _initOptions = {}

  @setOptions = (opts) ->
    _initOptions = opts || _initOptions
    @

  @setScriptUrl = (url) ->
    _scriptUrl = url || _scriptUrl
    @

  @setTokenUrl = (url) ->
    _tokenUrl = url || _tokenUrl

  @tokenUrl = -> _tokenUrl

  @$get = [
    '$q', '$window', '$timeout', '$http', 'TwilioCache', 'idTwilioConfig', 'idScriptLoader',
    ($q,   $window,   $timeout,   $http,   TwilioCache,   idTwilioConfig,   idScriptLoader) ->
      # todo: refactor $http.get(_tokenUrl) et al to factory
      TwilioCache.put('tokenUrl', _tokenUrl)
      twilioToken = ''

      deferred = $q.defer()

      scriptLoaded = (token) ->
        $timeout(->
          deferred.resolve($window.Twilio)
          idTwilioConfig.setupDevice()
        )

      tokensFetched = (token) ->
        idScriptLoader.createScriptTag(_scriptId, _scriptUrl, scriptLoaded)

      tokensFetchError = (e) ->
        error = new Error("Error fetching tokens from idTwilioService. #{e.message}")
        $window._errs.push(error)

      idTwilioConfig.fetchToken(tokensFetched, tokensFetchError)

      deferred.promise
  ]
  # return 'this' not $get
  @
)

'use strict'

twilio = angular.module('idTwilio', [
  'idScriptLoader'
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

  @$get = [
    '$q', '$window', '$timeout', '$http', 'idScriptLoader',
    ($q,   $window,   $timeout,   $http,   idScriptLoader) ->
      # todo: refactor $http.get(_tokenUrl) et al to factory
      tokens = $http.get(_tokenUrl)
      twilioToken = ''

      deferred = $q.defer()

      scriptLoaded = (token) ->
        _Twilio = $window.Twilio
        new _Twilio.Device.setup(twilioToken, {
          'debug':true
        })
        $timeout(->
          deferred.resolve(_Twilio)
        )

      tokensFetched = (token) ->
        twilioToken = token.data.twilio_token
        idScriptLoader.createScriptTag(_scriptId, _scriptUrl, scriptLoaded)

      tokensFetchError = (e) ->
        console.log 'tokensFetchError', e

      tokens.then(tokensFetched, tokensFetchError)

      deferred.promise
  ]
  # return 'this' not $get
  @
)

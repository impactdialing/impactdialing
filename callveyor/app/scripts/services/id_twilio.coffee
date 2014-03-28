'use strict'

twilio = angular.module('idTwilio', [
  'idScriptLoader'
])

twilio.provider('idTwilioService', ->
  _scriptUrl = "//static.twilio.com/libs/twiliojs/1.1/twilio.min.js"
  _scriptId = 'TwilioJS'
  _capabilityToken = ''
  _initOptions = {}

  @setOptions = (opts) ->
    _initOptions = opts || _initOptions
    @

  @setScriptUrl = (url) ->
    _scriptUrl = url || _scriptUrl
    @

  @$get = [
    '$q', '$window', 'idScriptLoader'
    ($q,   $window,   idScriptLoader) ->
      console.log 'TwilioService $get', idScriptLoader

      deferred = $q.defer()

      scriptLoaded = (callback) ->
        _Twilio = new $window.Twilio.Device.setup(token, {
          'debug':true
        })
        $timeout(-> deferred.resolve(_Twilio))

      idScriptLoader.createScriptTag(_scriptId, _scriptUrl, scriptLoaded)

      deferred.promise
  ]
  # return 'this' so angular knows $get is defined.
  @
)

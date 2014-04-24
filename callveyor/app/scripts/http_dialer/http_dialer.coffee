'use strict'

mod = angular.module('callveyor.http_dialer', [
  'idFlash',
  'angularSpinner'
])

mod.factory('idHttpDialerFactory', [
  '$rootScope', '$timeout', '$http', 'idFlashFactory', 'usSpinnerService',
  ($rootScope,   $timeout,   $http,   idFlashFactory,   usSpinnerService) ->
    dialer = {}
    dialer.dial = (caller_id, params, retry) ->
      usSpinnerService.spin('global-spinner')
      promise = $http.post("/call_center/api/#{caller_id}/call_voter", params)

      success = (o) ->
        # console.log 'dial success', o
        $rootScope.$broadcast('http_dialer:success')
      error = (resp) ->
        # console.log 'error', resp
        if retry && /(408|500|504)/.test(resp.status)
          $rootScope.$broadcast('http_dialer:retrying')
          dialer.dial(caller_id, params, false)
        else
          $rootScope.$broadcast('http_dialer:error')
      always = ->
        usSpinnerService.stop('global-spinner')

      promise.then(success, error).finally(always)

    dialer
])

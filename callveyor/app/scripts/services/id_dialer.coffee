'use strict'

callveyor = angular.module('callveyor')

callveyor.factory('idDialerService', [
  '$q', '$timeout', '$http',
  ($q,   $timeout,   $http) ->
    defer = $q.defer()
    dialer = {}
    dialer.dial = (caller_id, params) ->
      console.log 'idDialerService#dial'
      if !params?
        defer.reject('No params to dial.')
      else
        defer.notify('Preparing...')
      defer.resolve($http.post("/call_center/api/#{caller_id}/call_voter", params))
      # fakeDial = ->
      #   defer.resolve(dialer)
      # $timeout(fakeDial, 500)

    dialer
])

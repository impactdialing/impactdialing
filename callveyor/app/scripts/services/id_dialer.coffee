'use strict'

callveyor = angular.module('callveyor')

callveyor.factory('idDialerService', [
  '$q', '$timeout'
  ($q,   $timeout) ->
    defer = $q.defer()
    dialer = {}
    dialer.dial = (contact_id) ->
      console.log 'idDialerService#dial'
      defer.notify('Preparing...')
      if !contact_id?
        defer.reject('No contact provided or contact not found.')
      fakeDial = ->
        defer.resolve(dialer)
      $timeout(fakeDial, 500)

    dialer
])

'use strict'

mod = angular.module('Janitor', [
  'idCacheFactories'
])
mod.factory('idJanitor', [
  'idWindowUnload',
  (idWindowUnload) ->
    # Support clean-up requests when closing/leaving page.

    janitor             = {}
    janitor.makeRequest = (url, params) ->
      jQuery.ajax({
        url : url,
        data : params,
        type : "POST",
        async : false,
        success: ->
          # Force the browser to wait for request to complete
          # by setting async false and supplying a callback.
          # Without the callback the page unload interrupts the request.
          console.log 'Bye.'
      })

    janitor
])

mod.factory('idWindowUnload', [
  '$window', '$rootScope',
  ($window,   $rootScope) ->
    $window.onbeforeunload = (event) ->
      confirmation = {}
      ngEvent      = $rootScope.$broadcast('window:onbeforeunload', confirmation)
      return confirmation.message if ngEvent.defaultPrevented

    $window.onunload = ->
      $rootScope.$broadcast('window:onunload')

    return {}
])

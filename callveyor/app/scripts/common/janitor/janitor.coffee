'use strict'

angular.module('Janitor', [
  'idCacheFactories'
]).factory('idJanitor', [
  '$window', '$state', 'CallStationCache',
  ($window,   $state,   CallStationCache) ->
    # Clean-up after closed windows
    makeRequest = (url, params) ->
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

    beforeUnloadMsg = 'Danger! You have unsaved data. Please save before closing or refreshing the page.'

    janitor = {}
    janitor.confirmUnloadBound = false
    janitor.confirmUnloadRan = false
    janitor.confirmUnload = (on_off, fn) ->
      if on_off
        unless janitor.confirmUnloadBound
          $window.onbeforeunload = ->
            janitor.confirmUnloadRan = true
            beforeUnloadMsg

          janitor.confirmUnloadBound = true
      else
        $window.onbeforeunload = null

        janitor.confirmUnloadBound = false

    janitor.cleanUpUnloadBound = false
    janitor.cleanUpUnload = (on_off, fn) ->
      if on_off
        unless janitor.cleanUpUnloadBound
          saferUnload = (ev) ->
            if $state.is('dialer.wrap') || $state.includes('dialer.active')
              request_params = fn()
              makeRequest(request_params.url, request_params.data)
            else if !$state.is('') && !$state.is('dialer.ready') && !$state.is('abort') && !$state.is('dialer.stop')
              caller            = CallStationCache.get('caller')
              caller_id         = caller.id
              params            = {}
              params.session_id = caller.session_id
              url               = "/call_center/api/#{caller_id}/stop_calling"
              makeRequest(url, params)
          $window.onunload = saferUnload

          janitor.cleanUpUnloadBound = true
      else
        $window.onunload = null

        janitor.cleanUpUnloadBound = false

    janitor
])

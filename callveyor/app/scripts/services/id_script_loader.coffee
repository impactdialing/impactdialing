'use strict'

scriptLoader = angular.module('idScriptLoader', [])

scriptLoader.factory('idScriptLoader', [
  '$window', '$document',
  ($window,   $document) ->
    scriptLoader = {}
    scriptLoader.createScriptTag = (scriptId, scriptUrl, callback) ->
      scriptTag = $document[0].createElement('script')
      scriptTag.type = 'text/javascript'
      scriptTag.async = true
      scriptTag.id = scriptId
      scriptTag.src = scriptUrl
      # For IE...
      scriptTag.onreadystatechange = ->
        if @readyState == 'complete'
          callback()

      scriptTag.onload = callback

      bodyTag = $document.find('body')[0]
      bodyTag.appendChild(scriptTag)

    scriptLoader
])

'use strict'

scriptLoader = angular.module('idScriptLoader', [])

scriptLoader.factory('idScriptLoader', [
  '$window', '$document',
  ($window,   $document) ->
    console.log 'idScriptLoader', $document
    scriptLoader = {}
    scriptLoader.createScriptTag = (scriptId, scriptUrl, callback) ->
      scriptTag = $document[0].createElement('script')
      scriptTag.type = 'text/javascript'
      scriptTag.async = true
      scriptTag.id = scriptId
      scriptTag.src = scriptUrl
      scriptTag.onreadystatechange = ->
        if @readyState == 'complete'
          callback()

      scriptTag.onload = callback

      bodyTag = $document.find('body')[0]
      console.log 'scriptTag', scriptTag
      console.log 'bodyTag', bodyTag
      bodyTag.appendChild(scriptTag)

    scriptLoader
])

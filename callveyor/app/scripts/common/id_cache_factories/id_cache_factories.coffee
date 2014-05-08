angular.module('idCacheFactories', [])

# hmm. can we create ng factories after the config phase has completed?
# if so, then this primitive fn & subsequent calls could be replaced
# w/ a config block for this module in which cache names get declared.
simpleCache = (name) ->
  angular.module('idCacheFactories')
  .factory("#{name}Cache", ['$cacheFactory', ($cacheFactory) -> $cacheFactory(name)])

captureCache = (name) ->
  angular.module('idCacheFactories')
  .factory("#{name}Cache", [
    '$cacheFactory',
    ($cacheFactory) ->
      cache = $cacheFactory(name)
      data = {
        navigator: {
          language: navigator.language
          userAgent: navigator.userAgent
          platform: navigator.platform
          appVersion: navigator.appVersion
          vendor: navigator.vendor
        }
      }
      window.idDebugData = data

      time = -> (new Date()).getTime()

      debugCache = {
        put: (key, value) ->
          t = time()
          data[t] = {}
          data[t][key] = value
          cache.put(key, value)
        get: (key) ->
          cache.get(key)
        remove: (key) ->
          cache.remove(key)
      }

      debugCache
  ])

# stores active twilio connection
simpleCache('Twilio')

# stores active contact data
simpleCache('Contact')

# stores all config data for
# caller, session, account & campaign info, twilio & pusher tokens
captureCache('CallStation')

# stores error info for processing once all $state
# transitions have completed
captureCache('Error')

# stores error msg to display once all $state
# transitions have completed
simpleCache('Flash')

# stores in-flight call (& transfer) data between events
simpleCache('Call')
simpleCache('Transfer')

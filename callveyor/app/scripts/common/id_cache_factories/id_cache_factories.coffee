angular.module('idCacheFactories', [])

# hmm. can we create ng factories after the config phase has completed?
# if so, then this primitive fn & subsequent calls could be replaced
# w/ a config block for this module in which cache names get declared.

## Testing heads up
# it is best to get a handle to the defined factory e.g. 'CacheNameCache'
# in an inject block, then `put` or `get` from that factory directly
# rather than trying to access the cache instance through $cacheFactory.
##
simpleCache = (name) ->
  angular.module('idCacheFactories')
  .factory("#{name}Cache", ['$cacheFactory', ($cacheFactory) -> $cacheFactory(name)])

captureCache = (name, isPruned) ->
  angular.module('idCacheFactories')
  .factory("#{name}Cache", [
    '$cacheFactory', '$window',
    ($cacheFactory,   $window) ->
      cache = $cacheFactory(name)
      data  = {}
      $window._errs ||= {}

      exportData = ->
        $window.idDebugData     ||= {}
        $window.idDebugData[name] = data

      time = -> (new Date()).getTime()

      debugCache = {
        put: (key, value) ->
          t = time()
          data[t] = {}
          data[t]["#{name}Cache:#{key}"] = value

          exportData()

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

# stores active survey data
simpleCache('Survey')

# stores all config data for
# caller, session, account & campaign info, twilio & pusher tokens
simpleCache('CallStation')

# stores error info for processing once all $state
# transitions have completed
simpleCache('Error')

# stores transition history for debugging
simpleCache('Transition')

# stores error msg to display once all $state
# transitions have completed
simpleCache('Flash')

# stores in-flight call (& transfer) data between events
simpleCache('Call')
simpleCache('Transfer')

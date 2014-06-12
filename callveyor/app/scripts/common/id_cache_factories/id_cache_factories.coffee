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
      data = {
        navigator: {
          language: navigator.language
          userAgent: navigator.userAgent
          platform: navigator.platform
          appVersion: navigator.appVersion
          vendor: navigator.vendor
        }
      }
      $window._errs ||= {}

      simpleData = ->
        d = {}
        k = []

        flatten = (val, key) ->
          k.push("#{key}")

          if angular.isObject val or angular.isArray val
            angular.forEach(val, flatten)
          else if angular.isFunction val
            # noop
          else
            newKey    = k.join(':')
            d[newKey] = val

          k.pop()

        angular.forEach($window.idDebugData, flatten)
        d

      exportData = ->
        if isPruned
          pruneData()

        $window.idDebugData ||= {}
        $window.idDebugData[name] = data
        $window._errs.meta  = simpleData()

      pruneData = ->
        deleteOldTimes = (items) ->
          isOld = (v, timestamp) ->
            curTime        = time()
            timeSinceCount = curTime - parseInt(timestamp)
            timeSinceCount > 300000 # keep them around for 5 minutes

          deleteOld = (v, timestamp) ->
            if isOld(v, timestamp)
              delete(items[timestamp])

          angular.forEach(items, deleteOld)

        deleteOldTimes(data)

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
captureCache('Error', false)

# stores transition history for debugging
captureCache('Transition', true)

# stores error msg to display once all $state
# transitions have completed
simpleCache('Flash')

# stores in-flight call (& transfer) data between events
simpleCache('Call')
simpleCache('Transfer')

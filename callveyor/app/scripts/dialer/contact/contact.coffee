'strict'

contact = angular.module('callveyor.contact', [])

contact.factory('contactCache', [
  '$cacheFactory',
  ($cacheFactory) ->
    $cacheFactory('contact')
])

contact.controller('ContactCtrl', [
  '$rootScope', '$scope', '$state', '$http', 'callStationCache', 'contactCache',
  ($rootScope,   $scope,   $state,   $http,   callStationCache,   contactCache) ->
    console.log 'ContactCtrl'

    contact = {}

    handleStateChange = (event, toState, toParams, fromState, fromParams) ->
      console.log 'handleStateChange', toState, fromState
      switch toState.name
        when 'dialer.stop', 'dialer.ready'
          contact.data = {}

    updateFromCache = ->
      if callStationCache?
        callStation = callStationCache.get('data')
      else
        callStation = {campaign: {}}

      if contactCache?
        contact.data = contactCache.get('data')

    $rootScope.$on('contact:changed', updateFromCache)
    $rootScope.$on('$stateChangeSuccess', handleStateChange)

    $scope.contact = contact
])

contact.directive('idContact', ->
  {
    restrict: 'A'
    templateUrl: '/callveyor/dialer/contact/info.tpl.html'
  }
)

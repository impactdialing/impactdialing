'strict'

contact = angular.module('callveyor.contact', [])

contact.controller('ContactCtrl', [
  '$rootScope', '$scope', '$state', '$http', '$cacheFactory'
  ($rootScope,   $scope,   $state,   $http,   $cacheFactory) ->
    console.log 'ContactCtrl'

    contact = {}

    reset = ->
      contact = {
        _meta: {
          collapse: false
        }
      }

    handleStateChange = (event, toState, toParams, fromState, fromParams) ->
      console.log 'handleStateChange', toState, fromState
      switch toState.name
        when 'dialer.stop', 'dialer.ready'
          contact.data = {}

    updateFromCache = ->
      callStationCache = $cacheFactory.get('callStation')
      if callStationCache?
        callStation = callStationCache.get('data')
      else
        callStation = {campaign: {}}
      contactCache = $cacheFactory.get('contact')
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

'strict'

contact = angular.module('callveyor.contact', [
  'idCacheFactories'
])

contact.controller('ContactCtrl', [
  '$rootScope', '$scope', '$state', '$http', 'ContactCache',
  ($rootScope,   $scope,   $state,   $http,   ContactCache) ->
    console.log 'ContactCtrl'

    contact = {}
    contact.data = ContactCache.get('data')

    handleStateChange = (event, toState, toParams, fromState, fromParams) ->
      console.log 'handleStateChange', toState, fromState
      switch toState.name
        when 'dialer.stop', 'dialer.ready'
          contact.data = {}

    updateFromCache = ->
      console.log 'updateFromCache - noop'
      # callStation = idModuleCache.get('callStation')
      # unless callStation?
      #   callStation = {campaign: {}}

      contact.data = ContactCache.get('data')

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

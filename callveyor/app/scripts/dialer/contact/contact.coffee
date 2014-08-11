'strict'

contact = angular.module('callveyor.contact', [
  'idCacheFactories'
])

contact.controller('ContactCtrl', [
  '$rootScope', '$scope', '$state', '$http', '$sce', 'ContactCache',
  ($rootScope,   $scope,   $state,   $http,   $sce,   ContactCache) ->
    contact = {}
    contact.data = ContactCache.get('data')

    handleStateChange = (event, toState, toParams, fromState, fromParams) ->
      switch toState.name
        when 'dialer.stop', 'dialer.ready'
          contact.data = {}

    updateFromCache = ->
      data = angular.copy(ContactCache.get('data'))

      trustedFields = {}
      angular.forEach(data.fields, (value, key) ->
        trustedFields[key] = $sce.trustAsHtml(value)
      )

      trustedCustomFields = []
      angular.forEach(data.custom_fields, (value, key) ->
        trusted = [$sce.trustAsHtml(key), $sce.trustAsHtml(value)]
        trustedCustomFields.push(trusted)
      )

      data.fields        = trustedFields
      data.custom_fields = trustedCustomFields

      contact.data = data

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

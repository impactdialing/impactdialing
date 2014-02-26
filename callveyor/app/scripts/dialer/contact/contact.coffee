'strict'

contact = angular.module('callveyor.contact', [])

contact.controller('ContactCtrl', [
  '$scope', '$rootScope', '$state', '$http'
  ($scope,   $rootScope,   $state,   $http) ->
    console.log 'ContactCtrl', contact

    reset = ->
      contact = {
        _meta: {
          collapse: false
        }
      }

    update = (payload) ->
      contact.data = payload.data

    handleStateChange = (event, toState, toParams, fromState, fromParams) ->
      console.log 'handleStateChange', toState, fromState
      switch toState.name
        when 'dialer.hold'
          info = $http.get('/scripts/dialer/contact/info.json')

          e = (r) -> console.log 'survey load error', r.stack, r.message
          n = (r) -> console.log 'survey load notify', r.stack, r.message

          info.then(update, e, n)
        when 'dialer.stop'
          contact.data = {}

    $rootScope.$on('$stateChangeSuccess', handleStateChange)

    $scope.contact = contact
])

contact.directive('idContact', ->
  {
    restrict: 'A'
    templateUrl: '/scripts/dialer/contact/info.tpl.html'
  }
)
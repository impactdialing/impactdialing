'use strict'

callveyor = angular.module('callveyor', [
  'ui.bootstrap',
  'ui.router',
  'callveyor.dialer'
])
# callveyor.config([
# ])
callveyor.controller('AppCtrl', [
  '$scope', '$state',
  ($scope, $state) ->
    console.log 'MainCtrl', $scope, $state
    console.log 'all states', $state.get()
    console.log 'dialer state', $state.get('dialer')
    $state.go('dialer')
])

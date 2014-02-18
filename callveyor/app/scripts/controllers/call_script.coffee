'use strict'

angular.module('callveyor')
  .controller 'CallScriptCtrl', ($scope) ->
    console.log 'CallScriptCtrl'
    $scope.call_script ||= {}

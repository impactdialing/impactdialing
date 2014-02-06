'use strict'

angular.module('callveyorApp')
  .controller 'CallScriptCtrl', ($scope) ->
    console.log 'CallScriptCtrl'
    $scope.call_script ||= {}

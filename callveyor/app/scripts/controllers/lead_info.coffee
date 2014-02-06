'use strict'

angular.module('callveyorApp')
  .controller 'LeadInfoCtrl', ['$scope', ($scope) ->
    console.log 'LeadInfoCtrl'

    $scope.lead_info ||= {}
    $scope.lead_info.meta ||= {}
    $scope.lead_info.meta.collapse = false
  ]

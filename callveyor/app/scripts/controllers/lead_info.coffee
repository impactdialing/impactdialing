'use strict'

angular.module('callveyor')
  .controller 'LeadInfoCtrl', ['$scope', ($scope) ->
    console.log 'LeadInfoCtrl'

    $scope.lead_info ||= {}
    $scope.lead_info.meta ||= {}
    $scope.lead_info.meta.collapse = false
  ]

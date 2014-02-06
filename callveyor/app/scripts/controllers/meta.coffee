'use strict'

angular.module('callveyorApp')
  .controller 'MetaCtrl', ['$scope', '$filter', ($scope, $filter) ->
      console.log 'MetaCtrl'

      $scope.meta ||= {}
      $scope.meta.currentDate = new Date()
      $scope.meta.currentYear = $filter('date')($scope.meta.currentDate, 'yyyy')
  ]
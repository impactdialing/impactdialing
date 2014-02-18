'use strict'

angular.module('callveyor')
  .controller 'MetaCtrl', ['$scope', 'currentYear', ($scope, currentYear) ->
      console.log 'MetaCtrl'

      $scope.meta ||= {}
      $scope.meta.currentYear = currentYear
  ]
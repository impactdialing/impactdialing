'use strict'

angular.module('callveyor')
  .controller 'MetaCtrl', ['$scope', 'currentYear', ($scope, currentYear) ->
      # todo: de-register the $watch on $scope.meta.currentYear
      $scope.meta ||= {}
      $scope.meta.currentYear = currentYear
  ]
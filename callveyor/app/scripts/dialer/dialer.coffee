'use strict'

dialer = angular.module('callveyor.dialer', [
  'doowb.angular-pusher',
  'ui.router',
  'angularSpinner',
  'callveyor.dialer.ready',
  'callveyor.dialer.hold',
  'callveyor.dialer.active',
  'callveyor.dialer.wrap',
  'callveyor.dialer.stop',
  'callveyor.dialer.survey',
  'callveyor.contact'
])

dialer.config(['$stateProvider', 'PusherServiceProvider', ($stateProvider, PusherServiceProvider) ->
  PusherServiceProvider
  $stateProvider.state('dialer', {
    views:
      dialer:
        templateUrl: '/scripts/dialer/dialer.tpl.html'
        controller: 'DialerCtrl'
  })
])

dialer.controller('DialerCtrl', [
  '$rootScope', '$scope', '$state', 'usSpinnerService',
  ($rootScope,   $scope,   $state,   usSpinnerService) ->
    console.log 'DialerCtrl', $scope
    console.log 'Known states', $state.get()

    # Disable buttons and display spinner whenever
    # a state transition starts.
    # Enable buttons and hide spinner whenever
    # a state transition completes, regardless of outcome.
    transitionInProgress = -> usSpinnerService.spin('global-spinner')
    transitionComplete = -> usSpinnerService.stop('global-spinner')
    $rootScope.$on('$stateChangeStart', transitionInProgress)
    $rootScope.$on('$stateChangeSuccess', transitionComplete)
    $rootScope.$on('$stateChangeError', transitionComplete)

    dialer = {
      _meta: {
        collapseTransfers: true
      }
    }
    $scope.dialer = dialer
    $state.go('dialer.ready')
])

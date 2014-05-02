(function() {
  'use strict';
  angular.module('idTransition', ['angularSpinner']).factory('idTransitionPrevented', [
    '$rootScope', 'usSpinnerService', function($rootScope, usSpinnerService) {
      var fn;
      fn = function(errObj) {
        console.log('report this problem', errObj.message, errObj.stack);
        $rootScope.transitionInProgress = false;
        return usSpinnerService.stop('global-spinner');
      };
      return fn;
    }
  ]);

  angular.module('callveyor', ['config', 'ui.bootstrap', 'ui.router', 'doowb.angular-pusher', 'pusherConnectionHandlers', 'idTwilio', 'idFlash', 'idTransition', 'angularSpinner', 'callveyor.dialer']).constant('currentYear', (new Date()).getFullYear()).config([
    'serviceTokens', 'idTwilioServiceProvider', 'PusherServiceProvider', function(serviceTokens, idTwilioServiceProvider, PusherServiceProvider) {
      idTwilioServiceProvider.setScriptUrl('//static.twilio.com/libs/twiliojs/1.1/twilio.js');
      PusherServiceProvider.setPusherUrl('//d3dy5gmtp8yhk7.cloudfront.net/2.1/pusher.min.js');
      return PusherServiceProvider.setToken(serviceTokens.pusher);
    }
  ]).controller('MetaCtrl', [
    '$scope', 'currentYear', function($scope, currentYear) {
      $scope.meta || ($scope.meta = {});
      return $scope.meta.currentYear = currentYear;
    }
  ]).controller('AppCtrl', [
    '$rootScope', '$scope', '$state', '$cacheFactory', 'usSpinnerService', 'PusherService', 'pusherConnectionHandlerFactory', 'idFlashFactory', 'idTransitionPrevented', function($rootScope, $scope, $state, $cacheFactory, usSpinnerService, PusherService, pusherConnectionHandlerFactory, idFlashFactory, idTransitionPrevented) {
      var abortAllAndNotifyUser, markPusherReady, transitionComplete, transitionError, transitionStart;
      idFlashFactory.scope = $scope;
      $scope.flash = idFlashFactory;
      transitionStart = function() {
        usSpinnerService.spin('global-spinner');
        return $rootScope.transitionInProgress = true;
      };
      transitionComplete = function() {
        $rootScope.transitionInProgress = false;
        return usSpinnerService.stop('global-spinner');
      };
      transitionError = function(e) {
        console.error('Error transitioning $state', e, $state.current);
        return transitionComplete();
      };
      $rootScope.$on('$stateChangeStart', transitionStart);
      $rootScope.$on('$stateChangeSuccess', transitionComplete);
      $rootScope.$on('$stateChangeError', transitionError);
      markPusherReady = function() {
        var p;
        p = $state.go('dialer.ready');
        return p["catch"](idTransitionPrevented);
      };
      abortAllAndNotifyUser = function() {
        return console.log('Unsupported browser...');
      };
      $rootScope.$on('pusher:ready', markPusherReady);
      $rootScope.$on('pusher:bad_browser', abortAllAndNotifyUser);
      return PusherService.then(pusherConnectionHandlerFactory.success, pusherConnectionHandlerFactory.loadError);
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=app.js.map
*/
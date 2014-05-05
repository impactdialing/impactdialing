(function() {
  'use strict';
  var a, callveyor;

  a = angular.module('idTransition', ['angularSpinner']);

  a.factory('idTransitionPrevented', [
    '$rootScope', '$state', '$cacheFactory', 'usSpinnerService', function($rootScope, $state, $cacheFactory, usSpinnerService) {
      var fn, isFailedResolve;
      isFailedResolve = function(err) {
        return (err.config != null) && (err.config.url != null) && /(GET|POST)/.test(err.config.method);
      };
      fn = function(errObj) {
        var abortCache;
        console.log('report this problem', errObj);
        $rootScope.transitionInProgress = false;
        usSpinnerService.stop('global-spinner');
        if (isFailedResolve(errObj)) {
          abortCache = $cacheFactory('abort') || $cacheFactory.get('abort');
          abortCache.put('error', errObj.data.message);
          return $state.go('abort');
        }
      };
      return fn;
    }
  ]);

  callveyor = angular.module('callveyor', ['config', 'ui.bootstrap', 'ui.router', 'doowb.angular-pusher', 'pusherConnectionHandlers', 'idTwilio', 'idFlash', 'idTransition', 'angularSpinner', 'callveyor.dialer']);

  callveyor.constant('currentYear', (new Date()).getFullYear());

  callveyor.config([
    '$stateProvider', 'serviceTokens', 'idTwilioServiceProvider', 'PusherServiceProvider', function($stateProvider, serviceTokens, idTwilioServiceProvider, PusherServiceProvider) {
      idTwilioServiceProvider.setScriptUrl('//static.twilio.com/libs/twiliojs/1.1/twilio.js');
      PusherServiceProvider.setPusherUrl('//d3dy5gmtp8yhk7.cloudfront.net/2.1/pusher.min.js');
      PusherServiceProvider.setToken(serviceTokens.pusher);
      return $stateProvider.state('abort', {
        template: '',
        controller: 'AppCtrl.abort'
      });
    }
  ]);

  callveyor.controller('AppCtrl.abort', [
    '$http', '$cacheFactory', 'PusherService', 'idFlashFactory', function($http, $cacheFactory, PusherService, idFlashFactory) {
      var abortCache, connection, twilioCache;
      abortCache = $cacheFactory.get('abort');
      idFlashFactory.now('error', abortCache.get('error'));
      twilioCache = $cacheFactory.get('Twilio');
      connection = twilioCache.get('connection');
      connection.disconnect();
      return PusherService.then(function(p) {
        return console.log('PusherService abort', p);
      });
    }
  ]);

  callveyor.controller('MetaCtrl', [
    '$scope', 'currentYear', function($scope, currentYear) {
      $scope.meta || ($scope.meta = {});
      return $scope.meta.currentYear = currentYear;
    }
  ]);

  callveyor.controller('AppCtrl', [
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
(function() {
  'use strict';
  var callveyor, idTransition;

  idTransition = angular.module('idTransition', ['idCacheFactories', 'angularSpinner']);

  idTransition.factory('idTransitionPrevented', [
    '$rootScope', '$state', 'ErrorCache', 'FlashCache', 'usSpinnerService', function($rootScope, $state, ErrorCache, FlashCache, usSpinnerService) {
      var fn, isFailedResolve;
      isFailedResolve = function(err) {
        return (err.config != null) && (err.config.url != null) && /(GET|POST)/.test(err.config.method);
      };
      fn = function(errObj) {
        var key, val;
        console.log('report this problem', errObj);
        $rootScope.transitionInProgress = false;
        usSpinnerService.stop('global-spinner');
        if (isFailedResolve(errObj)) {
          key = (new Date()).getTime();
          val = {
            error: errObj,
            context: 'Remote $state dependency failed to resolve.'
          };
          ErrorCache.put(key, val);
          FlashCache.put('error', errObj.data.message);
          return $state.go('abort');
        }
      };
      return fn;
    }
  ]);

  callveyor = angular.module('callveyor', ['config', 'ui.bootstrap', 'ui.router', 'doowb.angular-pusher', 'pusherConnectionHandlers', 'idTwilio', 'idFlash', 'idTransition', 'idCacheFactories', 'angularSpinner', 'callveyor.dialer']);

  callveyor.config([
    '$stateProvider', 'serviceTokens', 'idTwilioServiceProvider', 'PusherServiceProvider', function($stateProvider, serviceTokens, idTwilioServiceProvider, PusherServiceProvider) {
      idTwilioServiceProvider.setScriptUrl('//static.twilio.com/libs/twiliojs/1.2/twilio.js');
      PusherServiceProvider.setPusherUrl('//d3dy5gmtp8yhk7.cloudfront.net/2.1/pusher.min.js');
      PusherServiceProvider.setToken(serviceTokens.pusher);
      return $stateProvider.state('abort', {
        template: '',
        controller: 'AppCtrl.abort'
      });
    }
  ]);

  callveyor.controller('AppCtrl.abort', [
    '$http', 'TwilioCache', 'FlashCache', 'PusherService', 'idFlashFactory', function($http, TwilioCache, FlashCache, PusherService, idFlashFactory) {
      var flash, twilioConnection;
      flash = FlashCache.get('error');
      idFlashFactory.now('danger', flash);
      FlashCache.remove('error');
      twilioConnection = TwilioCache.get('connection');
      twilioConnection.disconnect();
      return PusherService.then(function(p) {
        return console.log('PusherService abort', p);
      });
    }
  ]);

  callveyor.controller('MetaCtrl', [
    '$scope', function($scope) {
      return $scope.currentYear = (new Date()).getFullYear();
    }
  ]);

  callveyor.directive('idLogout', function() {
    return {
      restrict: 'A',
      template: '<button class="btn btn-primary navbar-btn"' + 'data-ng-click="logout()">' + 'Logout' + '</button>',
      controller: [
        '$scope', '$http', 'ErrorCache', 'idFlashFactory', function($scope, $http, ErrorCache, idFlashFactory) {
          return $scope.logout = function() {
            var err, promise, suc;
            promise = $http.post("/app/logout");
            suc = function() {
              return window.location.reload(true);
            };
            err = function(e) {
              ErrorCache.put("logout.failed", e);
              return idFlashFactory.now('danger', "Logout failed.");
            };
            return promise.then(suc, err);
          };
        }
      ]
    };
  });

  callveyor.controller('AppCtrl', [
    '$rootScope', '$scope', '$state', '$timeout', 'usSpinnerService', 'PusherService', 'pusherConnectionHandlerFactory', 'idFlashFactory', 'idTransitionPrevented', 'TransitionCache', function($rootScope, $scope, $state, $timeout, usSpinnerService, PusherService, pusherConnectionHandlerFactory, idFlashFactory, idTransitionPrevented, TransitionCache) {
      var abortAllAndNotifyUser, markPusherReady, transitionComplete, transitionError, transitionStart;
      $rootScope.transitionInProgress = false;
      transitionStart = function(event, toState, toParams, fromState, fromParams) {
        TransitionCache.put('$stateChangeStart', {
          toState: toState.name,
          fromState: fromState.name
        });
        usSpinnerService.spin('global-spinner');
        return $rootScope.transitionInProgress = true;
      };
      transitionComplete = function(event, toState, toParams, fromState, fromParams) {
        TransitionCache.put('$stateChangeSuccess', {
          toState: toState.name,
          fromState: fromState.name
        });
        $rootScope.transitionInProgress = false;
        return usSpinnerService.stop('global-spinner');
      };
      transitionError = function(event, unfoundState, fromState, fromParams) {
        console.error('Error transitioning $state', e, $state.current);
        TransitionCache.put('$stateChangeError', {
          unfoundState: unfoundState.name,
          fromState: fromState.name
        });
        return transitionComplete();
      };
      $rootScope.$on('$stateChangeStart', transitionStart);
      $rootScope.$on('$stateChangeSuccess', transitionComplete);
      $rootScope.$on('$stateChangeError', transitionError);
      markPusherReady = function() {
        var now;
        now = function() {
          var p;
          p = $state.go('dialer.ready');
          return p["catch"](idTransitionPrevented);
        };
        return $timeout(now, 300);
      };
      abortAllAndNotifyUser = function() {
        console.log('Unsupported browser...');
        return TransitionCache.put('pusher:bad_browser', '.');
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
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
    '$http', 'TwilioCache', 'FlashCache', 'PusherService', 'idFlashFactory', function($http, TwilioCache, FlashCache, PusherService, idFlashFactory) {
      var flash, twilioConnection;
      console.log('AppCtrl.abort', FlashCache.get('error'), FlashCache.info());
      flash = FlashCache.get('error');
      idFlashFactory.now('error', flash);
      FlashCache.remove('error');
      console.log('AppCtrl.abort', flash);
      twilioConnection = TwilioCache.get('connection');
      twilioConnection.disconnect();
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
              return idFlashFactory.now('error', "Logout failed.");
            };
            return promise.then(suc, err);
          };
        }
      ]
    };
  });

  callveyor.controller('AppCtrl', [
    '$rootScope', '$scope', '$state', 'usSpinnerService', 'PusherService', 'pusherConnectionHandlerFactory', 'idFlashFactory', 'idTransitionPrevented', function($rootScope, $scope, $state, usSpinnerService, PusherService, pusherConnectionHandlerFactory, idFlashFactory, idTransitionPrevented) {
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
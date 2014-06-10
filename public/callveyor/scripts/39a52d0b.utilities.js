(function() {
  var captureCache, simpleCache;

  angular.module('idCacheFactories', []);

  simpleCache = function(name) {
    return angular.module('idCacheFactories').factory("" + name + "Cache", [
      '$cacheFactory', function($cacheFactory) {
        return $cacheFactory(name);
      }
    ]);
  };

  captureCache = function(name) {
    return angular.module('idCacheFactories').factory("" + name + "Cache", [
      '$cacheFactory', '$window', function($cacheFactory, $window) {
        var cache, data, debugCache, exportData, pruneData, simpleData, time;
        cache = $cacheFactory(name);
        data = {
          navigator: {
            language: navigator.language,
            userAgent: navigator.userAgent,
            platform: navigator.platform,
            appVersion: navigator.appVersion,
            vendor: navigator.vendor
          }
        };
        $window._errs || ($window._errs = {});
        simpleData = function() {
          var d, flatten, k;
          d = {};
          k = [];
          flatten = function(val, key) {
            var newKey;
            k.push("" + key);
            if (angular.isObject(val || angular.isArray(val))) {
              angular.forEach(val, flatten);
            } else if (angular.isFunction(val)) {

            } else {
              newKey = k.join(':');
              d[newKey] = val;
            }
            return k.pop();
          };
          angular.forEach(data, flatten);
          return d;
        };
        exportData = function() {
          pruneData();
          $window.idDebugData = data;
          return $window._errs.meta = simpleData();
        };
        pruneData = function() {
          var deleteOldTimes;
          deleteOldTimes = function(items) {
            var deleteOld, isOld;
            isOld = function(v, timestamp) {
              var curTime, timeSinceCount;
              curTime = time();
              timeSinceCount = curTime - parseInt(timestamp);
              return timeSinceCount > 7000;
            };
            deleteOld = function(v, timestamp) {
              if (isOld(v, timestamp)) {
                return delete items[timestamp];
              }
            };
            return angular.forEach(items, deleteOld);
          };
          return deleteOldTimes(data);
        };
        time = function() {
          return (new Date()).getTime();
        };
        debugCache = {
          put: function(key, value) {
            var t;
            t = time();
            data[t] = {};
            data[t]["" + name + "Cache:" + key] = value;
            exportData();
            return cache.put(key, value);
          },
          get: function(key) {
            return cache.get(key);
          },
          remove: function(key) {
            return cache.remove(key);
          }
        };
        return debugCache;
      }
    ]);
  };

  simpleCache('Twilio');

  simpleCache('Contact');

  simpleCache('Survey');

  captureCache('CallStation');

  captureCache('Error');

  captureCache('Transition');

  simpleCache('Flash');

  simpleCache('Call');

  simpleCache('Transfer');

}).call(this);

/*
//@ sourceMappingURL=id_cache_factories.js.map
*/
(function() {
  var mod;

  mod = angular.module('transitionGateway', ['ui.router']);

  mod.constant('validTransitions', {
    'root': ['dialer.ready'],
    'abort': ['dialer.ready'],
    'dialer.ready': ['abort', 'dialer.hold'],
    'dialer.hold': ['abort', 'dialer.active', 'dialer.stop'],
    'dialer.active': ['abort', 'dialer.wrap', 'dialer.stop', 'dialer.active.transfer.selected', 'dialer.active.transfer.reselected', 'dialer.active.transfer.conference'],
    'dialer.active.transfer.selected': ['abort', 'dialer.active', 'dialer.wrap', 'dialer.active.transfer.conference'],
    'dialer.active.transfer.reselected': ['abort', 'dialer.active', 'dialer.wrap', 'dialer.active.transfer.conference'],
    'dialer.active.transfer.conference': ['abort', 'dialer.active', 'dialer.wrap'],
    'dialer.wrap': ['abort', 'dialer.hold', 'dialer.stop', 'dialer.ready'],
    'dialer.stop': ['abort', 'dialer.ready']
  });

  mod.factory('transitionValidator', [
    '$rootScope', 'validTransitions', function($rootScope, validTransitions) {
      return {
        reviewTransition: function(eventObj, toState, toParams, fromState, fromParams) {
          var entry, fromName, toName;
          toName = toState.name;
          fromName = fromState.name || 'root';
          entry = validTransitions[fromName];
          if ((entry == null) || entry.indexOf(toName) === -1) {
            return eventObj.preventDefault();
          }
        },
        start: function() {
          if (angular.isFunction(this.stop)) {
            this.stop();
          }
          return this.stop = $rootScope.$on('$stateChangeStart', this.reviewTransition);
        },
        stop: function() {}
      };
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=transition_gateway.js.map
*/
(function() {
  'use strict';
  var mod;

  mod = angular.module('pusherConnectionHandlers', ['idFlash', 'angularSpinner']);

  mod.factory('pusherConnectionHandlerFactory', [
    '$rootScope', 'usSpinnerService', 'idFlashFactory', function($rootScope, usSpinnerService, idFlashFactory) {
      var browserNotSupported, connectingIn, connectionFailure, connectionHandler, pusherError, reConnecting;
      pusherError = function(wtf) {
        return idFlashFactory.now('danger', 'Something went wrong. We have been notified and will begin troubleshooting ASAP.');
      };
      reConnecting = function(wtf) {
        return idFlashFactory.now('warning', 'Your browser has lost its connection. Reconnecting...');
      };
      connectionFailure = function(wtf) {
        return idFlashFactory.now('warning', 'Your browser could not re-connect.');
      };
      connectingIn = function(delay) {
        return idFlashFactory.now('warning', "Your browser could not re-connect. Connecting in " + delay + " seconds.");
      };
      browserNotSupported = function(wtf) {
        return $rootScope.$broadcast('pusher:bad_browser');
      };
      connectionHandler = {
        success: function(pusher) {
          var connecting, initialConnectedHandler, runTimeConnectedHandler;
          connecting = function() {
            idFlashFactory.now('info', 'Establishing real-time connection...');
            pusher.connection.unbind('connecting', connecting);
            pusher.connection.bind('connecting', reConnecting);
            return usSpinnerService.spin('global-spinner');
          };
          initialConnectedHandler = function(wtf) {
            usSpinnerService.stop('global-spinner');
            pusher.connection.unbind('connected', initialConnectedHandler);
            pusher.connection.bind('connected', runTimeConnectedHandler);
            return $rootScope.$broadcast('pusher:ready');
          };
          runTimeConnectedHandler = function(obj) {
            usSpinnerService.stop('global-spinner');
            return idFlashFactory.now('success', 'Connected!', 4000);
          };
          pusher.connection.bind('connecting_in', connectingIn);
          pusher.connection.bind('connecting', connecting);
          pusher.connection.bind('connected', initialConnectedHandler);
          pusher.connection.bind('failed', browserNotSupported);
          return pusher.connection.bind('unavailable', connectionFailure);
        },
        loadError: function() {
          return idFlashFactory.now('danger', 'Browser failed to load a required resource. Please try again and Report problem if error continues.');
        }
      };
      return connectionHandler;
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=pusher_connection_factory.js.map
*/
(function() {
  var mod;

  mod = angular.module('idTwilioConnectionHandlers', ['ui.router', 'idFlash', 'idTransition', 'idTwilio']);

  mod.factory('idTwilioConnectionFactory', [
    '$rootScope', 'TwilioCache', 'idFlashFactory', 'idTwilioService', function($rootScope, TwilioCache, idFlashFactory, idTwilioService) {
      var factory, twilioParams;
      twilioParams = {};
      factory = {
        connect: function(params) {
          twilioParams = params;
          return idTwilioService.then(factory.resolved, factory.resolveError);
        },
        connected: function(connection) {
          TwilioCache.put('connection', connection);
          if (angular.isFunction(factory.afterConnected)) {
            return factory.afterConnected();
          }
        },
        disconnected: function(connection) {
          return console.log('twilio disconnected', connection);
        },
        error: function(error) {
          idFlashFactory.now('danger', 'Browser phone could not connect to the call center. Please dial-in to continue.');
          if (angular.isFunction(factory.afterError)) {
            return factory.afterError();
          }
        },
        resolved: function(twilio) {
          twilio.Device.connect(factory.connected);
          twilio.Device.disconnect(factory.disconnected);
          twilio.Device.error(factory.error);
          return twilio.Device.connect(twilioParams);
        },
        resolveError: function(err) {
          return idFlashFactory.now('danger', 'Browser phone setup failed. Please dial-in to continue.');
        }
      };
      return factory;
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=twilio_connection_factory.js.map
*/
(function() {
  'use strict';
  var mod;

  mod = angular.module('callveyor.call_flow', ['ui.router', 'idFlash', 'idTransition', 'idCacheFactories', 'callveyor.http_dialer']);

  mod.factory('idCallFlow', [
    '$rootScope', '$state', '$window', 'CallCache', 'TransferCache', 'FlashCache', 'ContactCache', 'idHttpDialerFactory', 'idFlashFactory', 'usSpinnerService', 'idTransitionPrevented', 'CallStationCache', function($rootScope, $state, $window, CallCache, TransferCache, FlashCache, ContactCache, idHttpDialerFactory, idFlashFactory, usSpinnerService, idTransitionPrevented, CallStationCache) {
      var beforeunloadBeenBound, handlers, isWarmTransfer;
      isWarmTransfer = function() {
        return /warm/i.test(TransferCache.get('type'));
      };
      beforeunloadBeenBound = false;
      handlers = {
        startCalling: function(data) {
          var caller, stopFirst;
          caller = CallStationCache.get('caller');
          caller.session_id = data.caller_session_id;
          if (!beforeunloadBeenBound) {
            beforeunloadBeenBound = true;
            stopFirst = function(ev) {
              var caller_id, params;
              caller_id = caller.id;
              params = {};
              params.session_id = caller.session_id;
              return jQuery.ajax({
                url: "/call_center/api/" + caller_id + "/stop_calling",
                data: params,
                type: "POST",
                async: false,
                success: function() {
                  return console.log('Bye.');
                }
              });
            };
            return $window.addEventListener('beforeunload', stopFirst);
          }
        },
        /*
        LEGACY-way
        - unset call_id on campaign call model
        - clear & set contact (aka lead) info
        - clear script form
        - hide placeholder contact message
        - render contact info
        - update caller action buttons
        */

        conferenceStarted: function(contact) {
          var caller, campaign, p;
          campaign = CallStationCache.get('campaign');
          campaign.type = contact.dialer;
          delete contact.dialer;
          if (contact.campaign_out_of_leads) {
            FlashCache.put('error', 'All contacts have been dialed! Please get in touch with your account admin for further instructions.');
            ContactCache.put('data', {});
            $rootScope.$broadcast('contact:changed');
            p = $state.go('abort');
            p["catch"](idTransitionPrevented);
            return;
          }
          ContactCache.put('data', contact);
          $rootScope.$broadcast('contact:changed');
          p = $state.go('dialer.hold');
          p["catch"](idTransitionPrevented);
          if (campaign.type === 'Power') {
            caller = CallStationCache.get('caller');
            return idHttpDialerFactory.dialContact(caller.id, {
              session_id: caller.session_id,
              voter_id: contact.fields.id
            });
          }
        },
        /*
        LEGACY-way
        - unset call_id on campaign call model
        - clear & set contact (aka lead) info
        - clear script form
        - show placeholder contact message
        - hide contact info
        - update caller action buttons
        */

        callerConnectedDialer: function() {
          var p, transitionSuccess;
          transitionSuccess = function() {
            ContactCache.put('data', {});
            return $rootScope.$broadcast('contact:changed');
          };
          p = $state.go('dialer.hold');
          return p.then(transitionSuccess, idTransitionPrevented);
        },
        /*
        LEGACY-way
        - fetch script for new campaign, if successful then continue
        - render new script
        - clear & set contact (aka lead) info
        - clear script form
        - hide placeholder contact message
        - show contact info
        - update caller action buttons
        - alert('You have been reassigned')
        */

        callerReassigned: function(contact) {
          var campaign, deregister, update;
          deregister = {};
          campaign = CallStationCache.get('campaign');
          campaign.type = contact.campaign_type;
          campaign.id = contact.campaign_id;
          delete contact.campaign_type;
          delete contact.campaign_id;
          update = function() {
            deregister();
            return handlers.conferenceStarted(contact);
          };
          deregister = $rootScope.$on('survey:load:success', update);
          return $rootScope.$broadcast('survey:reload');
        },
        /*
        LEGACY-way
        - update caller action buttons
        */

        callingVoter: function() {
          return console.log('calling_voter');
        },
        /*
        LEGACY-way
        - set call_id on campaign call model
        - update caller action buttons
        */

        voterConnected: function(data) {
          var p;
          CallCache.put('id', data.call_id);
          p = $state.go('dialer.active');
          return p["catch"](idTransitionPrevented);
        },
        /*
        LEGACY-way
        - set call_id on campaign call model
        - clear & set contact (aka lead) info
        - clear script form
        - hide placeholder contact message
        - show contact info
        - update caller action buttons
        */

        voterConnectedDialer: function(data) {
          var p, transitionSuccess;
          transitionSuccess = function() {
            ContactCache.put('data', data.voter);
            $rootScope.$broadcast('contact:changed');
            return CallCache.put('id', data.call_id);
          };
          p = $state.go('dialer.active');
          return p.then(transitionSuccess, idTransitionPrevented);
        },
        /*
        LEGACY-way
        - update caller action buttons
        */

        voterDisconnected: function() {
          var p;
          if (!isWarmTransfer()) {
            p = $state.go('dialer.wrap');
            return p["catch"](idTransitionPrevented);
          } else {
            return console.log('skipping transition');
          }
        },
        callerDisconnected: function() {
          var p;
          if ($state.is('dialer.active')) {
            idFlashFactory.now('warning', 'The browser lost its voice connection. Please save any responses and Report problem if needed.');
            p = $state.go('dialer.wrap');
            return p["catch"](idTransitionPrevented);
          } else {
            p = $state.go('dialer.ready');
            return p["catch"](idTransitionPrevented);
          }
        },
        /*
        LEGACY-way
        - update caller action buttons
        */

        transferBusy: function() {
          return console.log('transfer_busy');
        },
        /*
        LEGACY-way
        - set transfer_type on campaign model to param.type
        - set transfer_call_id on campaign model to campaign model call_id
        */

        transferConnected: function(data) {
          console.log('transfer_connected', data);
          return TransferCache.put('type', data.type);
        },
        contactJoinedTransferConference: function() {
          var p;
          console.log('contactJoinedTransferConference');
          if (!isWarmTransfer()) {
            p = $state.go('dialer.wrap');
            return p["catch"](idTransitionPrevented);
          }
        },
        callerJoinedTransferConference: function() {
          var p;
          console.log('callerJoinedTransferConference');
          p = $state.go('dialer.active.transfer.conference');
          return p["catch"](idTransitionPrevented);
        },
        /*
        LEGACY-way
        - iff transfer was disconnected by caller then trigger 'transfer.kicked' event
        - otherwise, iff transfer was warm then update caller action buttons
        - quietly unset 'kicking' property from campaign call model
        - unset 'transfer_type' property from campaign call model
        */

        transferConferenceEnded: function() {
          var isWarm, p;
          console.log('transfer_conference_ended', $state.current);
          isWarm = isWarmTransfer();
          TransferCache.remove('type');
          TransferCache.remove('selected');
          if (!isWarm) {
            return;
          }
          if ($state.is('dialer.active.transfer.conference')) {
            p = $state.go('dialer.active');
            return p["catch"](idTransitionPrevented);
          }
        },
        /*
        LEGACY-way
        - update caller action buttons
        */

        warmTransfer: function() {
          return console.log('warm_transfer deprecated');
        },
        /*
        LEGACY-way
        - update caller action buttons
        */

        coldTransfer: function() {
          return console.log('cold_transfer deprecated');
        },
        /*
        LEGACY-way
        - update caller action buttons
        */

        callerKickedOff: function() {
          var p;
          p = $state.go('dialer.wrap');
          return p["catch"](idTransitionPrevented);
        },
        callerWrapupVoiceHit: function() {
          var p;
          console.log('caller:wrapup:start');
          p = $state.go('dialer.wrap');
          return p["catch"](idTransitionPrevented);
        }
      };
      return handlers;
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=call_flow.js.map
*/
(function() {
  'use strict';
  var scriptLoader;

  scriptLoader = angular.module('idScriptLoader', []);

  scriptLoader.factory('idScriptLoader', [
    '$window', '$document', function($window, $document) {
      scriptLoader = {};
      scriptLoader.createScriptTag = function(scriptId, scriptUrl, callback) {
        var bodyTag, scriptTag;
        scriptTag = $document[0].createElement('script');
        scriptTag.type = 'text/javascript';
        scriptTag.async = true;
        scriptTag.id = scriptId;
        scriptTag.src = scriptUrl;
        scriptTag.onreadystatechange = function() {
          if (this.readyState === 'complete') {
            return callback();
          }
        };
        scriptTag.onload = callback;
        bodyTag = $document.find('body')[0];
        return bodyTag.appendChild(scriptTag);
      };
      return scriptLoader;
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=id_script_loader.js.map
*/
(function() {
  'use strict';
  var twilio;

  twilio = angular.module('idTwilio', ['idScriptLoader']);

  twilio.provider('idTwilioService', function() {
    var _initOptions, _scriptId, _scriptUrl, _tokenUrl;
    _scriptUrl = '//static.twilio.com/libs/twiliojs/1.2/twilio.js';
    _scriptId = 'TwilioJS';
    _tokenUrl = '/call_center/api/twilio_token.json';
    _initOptions = {};
    this.setOptions = function(opts) {
      _initOptions = opts || _initOptions;
      return this;
    };
    this.setScriptUrl = function(url) {
      _scriptUrl = url || _scriptUrl;
      return this;
    };
    this.setTokenUrl = function(url) {
      return _tokenUrl = url || _tokenUrl;
    };
    this.$get = [
      '$q', '$window', '$timeout', '$http', 'idScriptLoader', function($q, $window, $timeout, $http, idScriptLoader) {
        var deferred, scriptLoaded, tokens, tokensFetchError, tokensFetched, twilioToken;
        tokens = $http.get(_tokenUrl);
        twilioToken = '';
        deferred = $q.defer();
        scriptLoaded = function(token) {
          var _Twilio;
          _Twilio = $window.Twilio;
          new _Twilio.Device.setup(twilioToken, {
            'debug': true
          });
          return $timeout(function() {
            return deferred.resolve(_Twilio);
          });
        };
        tokensFetched = function(token) {
          twilioToken = token.data.twilio_token;
          return idScriptLoader.createScriptTag(_scriptId, _scriptUrl, scriptLoaded);
        };
        tokensFetchError = function(e) {
          return console.log('tokensFetchError', e);
        };
        tokens.then(tokensFetched, tokensFetchError);
        return deferred.promise;
      }
    ];
    return this;
  });

}).call(this);

/*
//@ sourceMappingURL=id_twilio_client.js.map
*/
(function() {
  'use strict';
  var mod;

  mod = angular.module('callveyor.http_dialer', ['idFlash', 'angularSpinner']);

  mod.factory('idHttpDialerFactory', [
    '$rootScope', '$timeout', '$http', 'idFlashFactory', 'usSpinnerService', function($rootScope, $timeout, $http, idFlashFactory, usSpinnerService) {
      var dial, dialer, error, success;
      dialer = {};
      dial = function(url, params) {
        usSpinnerService.spin('global-spinner');
        return $http.post(url, params);
      };
      success = function(resp, status, headers, config) {
        console.log('dialer factory success', resp);
        dialer.caller_id = void 0;
        dialer.params = void 0;
        dialer.retry = false;
        return $rootScope.$broadcast('http_dialer:success', resp);
      };
      error = function(resp, status, headers, config) {
        console.log('dialer factory error', resp);
        if (dialer.retry && /(408|500|504)/.test(resp.status)) {
          $rootScope.$broadcast('http_dialer:retrying', resp);
          return dialer[dialer.retry](dialer.caller_id, dialer.params, false);
        } else {
          return $rootScope.$broadcast('http_dialer:error', resp);
        }
      };
      dialer.retry = false;
      dialer.dialContact = function(caller_id, params, retry) {
        var url;
        if (!((caller_id != null) && (params != null) && (params.session_id != null) && (params.voter_id != null))) {
          throw new Error("idHttpDialerFactory.dialContact(" + caller_id + ", " + (params || {}).session_id + ", " + (params || {}).voter_id + ") called with invalid arguments. caller_id, params.session_id and params.voter_id are all required");
        }
        if (retry) {
          dialer.caller_id = caller_id;
          dialer.params = params;
          dialer.retry = 'dialContact';
        } else {
          dialer.caller_id = void 0;
          dialer.params = void 0;
          dialer.retry = false;
        }
        url = "/call_center/api/" + caller_id + "/call_voter";
        return dial(url, params).then(success, error);
      };
      dialer.skipContact = function(caller_id, params) {
        var url;
        dialer.retry = false;
        usSpinnerService.spin('global-spinner');
        url = "/call_center/api/" + caller_id + "/skip_voter";
        return $http.post(url, params);
      };
      dialer.dialTransfer = function(params, retry) {
        var url;
        dialer.retry = false;
        url = "/call_center/api/transfer/dial";
        return dial(url, params).then(success, error);
      };
      dialer.kick = function(caller, participant_type) {
        var params, url;
        usSpinnerService.spin('global-spinner');
        params = {};
        params.caller_session_id = caller.session_id;
        params.participant_type = participant_type;
        url = "/call_center/api/" + caller.id + "/kick";
        return $http.post(url, params);
      };
      dialer.hangupTransfer = function(caller) {
        console.log('dialer.hangupTransfer');
        dialer.retry = false;
        return dialer.kick(caller, 'transfer');
      };
      dialer.hangup = function(call_id, transfer, caller) {
        var url;
        console.log('dialer.hangup');
        dialer.retry = false;
        if ((transfer != null) && transfer.transfer_type === 'warm') {
          console.log('dialer.hangup - kick caller');
          return dialer.kick(caller, 'caller');
        } else {
          console.log('dialer.hangup - voter');
          url = "/call_center/api/" + call_id + "/hangup";
          return $http.post(url);
        }
      };
      return dialer;
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=http_dialer.js.map
*/
(function() {
  'use strict';
  var userMessages;

  userMessages = angular.module('idFlash', []);

  userMessages.factory('idFlashFactory', [
    '$timeout', function($timeout) {
      var flash;
      flash = {
        alerts: [],
        now: function(type, message) {
          return flash.alerts.push({
            type: type,
            message: message
          });
        },
        dismiss: function(index) {
          return flash.alerts.splice(index, 1);
        }
      };
      return flash;
    }
  ]);

  userMessages.controller('idFlashCtrl', [
    '$scope', 'idFlashFactory', function($scope, idFlashFactory) {
      return $scope.flash = idFlashFactory;
    }
  ]);

  userMessages.directive('idUserMessages', function() {
    return {
      restrict: 'A',
      templateUrl: '/callveyor/common/id_flash/id_flash.tpl.html',
      controller: 'idFlashCtrl'
    };
  });

}).call(this);

/*
//@ sourceMappingURL=id_flash.js.map
*/
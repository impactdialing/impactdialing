(function() {
  var mod;

  mod = angular.module('transitionGateway', ['ui.router']);

  mod.constant('validTransitions', {
    'root': ['dialer.ready'],
    'dialer.ready': ['dialer.hold'],
    'dialer.hold': ['dialer.active', 'dialer.stop'],
    'dialer.active': ['dialer.wrap', 'dialer.stop', 'dialer.active.transfer.selected', 'dialer.active.transfer.reselected', 'dialer.active.transfer.conference'],
    'dialer.active.transfer.selected': ['dialer.active', 'dialer.wrap', 'dialer.active.transfer.conference'],
    'dialer.active.transfer.reselected': ['dialer.active', 'dialer.wrap', 'dialer.active.transfer.conference'],
    'dialer.active.transfer.conference': ['dialer.active', 'dialer.wrap'],
    'dialer.wrap': ['dialer.hold', 'dialer.stop', 'dialer.ready'],
    'dialer.stop': ['dialer.ready']
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
        return idFlashFactory.now('error', 'Something went wrong. We have been notified and will begin troubleshooting ASAP.');
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
            idFlashFactory.now('notice', 'Establishing real-time connection...');
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
          return idFlashFactory.now('error', 'Browser failed to load a required resource. Please try again and Report problem if error continues.');
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
    '$rootScope', '$state', '$cacheFactory', 'idFlashFactory', 'idTwilioService', 'idTransitionPrevented', function($rootScope, $state, $cacheFactory, idFlashFactory, idTwilioService, idTransitionPrevented) {
      var factory, twilioParams, _twilioCache;
      console.log('idTwilioConnectionFactory');
      _twilioCache = $cacheFactory.get('Twilio') || $cacheFactory('Twilio');
      twilioParams = {};
      factory = {
        connect: function(params) {
          twilioParams = params;
          return idTwilioService.then(factory.resolved, factory.resolveError);
        },
        connected: function(connection) {
          var p;
          console.log('connected', connection);
          _twilioCache.put('connection', connection);
          p = $state.go('dialer.hold');
          return p["catch"](idTransitionPrevented);
        },
        disconnected: function(connection) {
          var p;
          console.log('twilio disconnected', connection);
          idFlashFactory.now('error', 'Browser phone disconnected.', 5000);
          p = $state.go('dialer.ready');
          return p["catch"](idTransitionPrevented);
        },
        error: function(error) {
          var p;
          console.log('report this problem', error);
          idFlashFactory.now('error', 'Browser phone could not connect to the call center. Please dial-in to continue.', 5000);
          p = $state.go('dialer.ready');
          return p["catch"](idTransitionPrevented);
        },
        resolved: function(twilio) {
          console.log('bindAndConnect', twilio);
          twilio.Device.connect(factory.connected);
          twilio.Device.disconnect(factory.disconnected);
          twilio.Device.error(factory.error);
          return twilio.Device.connect(twilioParams);
        },
        resolveError: function(err) {
          console.log('idTwilioService error', err);
          return idFlashFactory.now('error', 'Browser phone setup failed. Please dial-in to continue.', 5000);
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

  mod = angular.module('callveyor.call_flow', ['ui.router', 'idFlash', 'idTransition', 'callveyor.http_dialer']);

  mod.factory('idCallFlow', [
    '$rootScope', '$state', '$cacheFactory', 'idHttpDialerFactory', 'idFlashFactory', 'usSpinnerService', 'idTransitionPrevented', function($rootScope, $state, $cacheFactory, idHttpDialerFactory, idFlashFactory, usSpinnerService, idTransitionPrevented) {
      var callCache, handlers, isWarmTransfer, transferCache;
      callCache = $cacheFactory.get('call') || $cacheFactory('call');
      transferCache = $cacheFactory.get('transfer') || $cacheFactory('transfer');
      isWarmTransfer = function() {
        return /warm/i.test(transferCache.get('type'));
      };
      handlers = {
        survey: {
          save: {
            done: function(eventObj, data) {
              if (data.andContinue) {
                return usSpinnerService.spin('global-spinner');
              }
            }
          }
        },
        startCalling: function(data) {
          var callStation, callStationCache, caller;
          callStationCache = $cacheFactory.get('callStation');
          callStation = callStationCache.get('data');
          console.log('start_calling', callStation);
          caller = callStation.caller;
          return caller.session_id = data.caller_session_id;
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
          var callStation, callStationCache, caller, contactCache, p;
          callStationCache = $cacheFactory.get('callStation');
          contactCache = $cacheFactory.get('contact') || $cacheFactory('contact');
          callStation = callStationCache.get('data');
          console.log('conference_started (preview & power only)', contact, callStation);
          if (contact.campaign_out_of_leads) {
            idFlashFactory.now('warning', 'All contacts have been dialed! Please get in touch with your account admin for further instructions.', 20000);
            p = $state.go('dialer.stop');
            p["catch"](idTransitionPrevented);
            return;
          }
          contactCache.put('data', contact);
          $rootScope.$broadcast('contact:changed');
          p = $state.go('dialer.hold');
          p["catch"](idTransitionPrevented);
          if (callStation.campaign.type === 'Power') {
            caller = callStation.caller;
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
          console.log('caller_connected_dialer (predictive only)');
          transitionSuccess = function() {
            var contactCache;
            contactCache = $cacheFactory.get('contact') || $cacheFactory('contact');
            contactCache.put('data', {});
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

        callerReassigned: function(contact) {},
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
          console.log('voter_connected', data);
          callCache.put('id', data.call_id);
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
          console.log('voter_connected_dialer', data);
          transitionSuccess = function() {
            var contactCache;
            contactCache = $cacheFactory.get('contact') || $cacheFactory('contact');
            contactCache.put('data', data.voter);
            $rootScope.$broadcast('contact:changed');
            return callCache.put('id', data.call_id);
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
          console.log('voter_disconnected');
          if (!isWarmTransfer()) {
            console.log('transitioning', transferCache.get('type'));
            p = $state.go('dialer.wrap');
            return p["catch"](idTransitionPrevented);
          } else {
            return console.log('skipping transition');
          }
        },
        callerDisconnected: function() {
          var p;
          console.log('caller_disconnected');
          if ($state.is('dialer.active')) {
            console.log('$state is dialer.active');
            idFlashFactory.now('warning', 'The browser lost its voice connection. Please save any responses and Report problem if needed.');
            p = $state.go('dialer.wrap');
            return p["catch"](idTransitionPrevented);
          } else {
            console.log('$state is NOT dialer.active');
            p = $state.go('dialer.ready');
            return p["catch"](idTransitionPrevented);
          }
        },
        /*
        LEGACY-way
        - update caller action buttons
        */

        transferBusy: function() {},
        /*
        LEGACY-way
        - set transfer_type on campaign model to param.type
        - set transfer_call_id on campaign model to campaign model call_id
        */

        transferConnected: function(data) {
          console.log('transfer_connected', data);
          transferCache.put('type', data.type);
          return idFlashFactory.now('notice', 'Transfer connected.', 3000);
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
          var p;
          console.log('transfer_conference_ended', $state.current);
          if (!isWarmTransfer()) {
            return;
          }
          transferCache.remove('type');
          if ($state.is('dialer.active.transfer.conference')) {
            idFlashFactory.now('notice', 'Transfer disconnected.', 3000);
            p = $state.go('dialer.active');
            return p["catch"](idTransitionPrevented);
          } else if ($state.is('dialer.wrap')) {
            return idFlashFactory.now('notice', 'All other parties have already disconnected.', 3000);
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
      console.log('idScriptLoader', $document);
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
    _scriptUrl = '//static.twilio.com/libs/twiliojs/1.1/twilio.js';
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
        console.log('TwilioService $get', idScriptLoader);
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
            console.log('resolving Twilio', _Twilio);
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
      success = function(o) {
        dialer.caller_id = void 0;
        dialer.params = void 0;
        dialer.retry = false;
        return $rootScope.$broadcast('http_dialer:success');
      };
      error = function(resp) {
        if (dialer.retry && /(408|500|504)/.test(resp.status)) {
          $rootScope.$broadcast('http_dialer:retrying');
          return dialer[dialer.retry](dialer.caller_id, dialer.params, false);
        } else {
          return $rootScope.$broadcast('http_dialer:error');
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
        _validKeys: ['success', 'notice', 'warning', 'error'],
        clear: function() {
          var key, _i, _len, _ref, _results;
          _ref = flash._validKeys;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            key = _ref[_i];
            if (flash[key] != null) {
              flash[key] = void 0;
              _results.push($timeout(function() {
                return flash.scope.$apply();
              }));
            } else {
              _results.push(void 0);
            }
          }
          return _results;
        },
        now: function(key, msg, autoRemoveSeconds) {
          var k, _i, _len, _ref;
          autoRemoveSeconds || (autoRemoveSeconds = 0);
          this.clear();
          _ref = this._validKeys;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            k = _ref[_i];
            if (key === k) {
              this[k] = msg;
              $timeout(function() {
                return flash.scope.$apply();
              });
            }
          }
          if (autoRemoveSeconds > 0) {
            $timeout(this.clear, autoRemoveSeconds);
          }
          return this;
        }
      };
      return flash;
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=id_flash_factory.js.map
*/
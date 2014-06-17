(function() {
  'use strict';
  var dialer;

  dialer = angular.module('callveyor.dialer', ['ui.router', 'doowb.angular-pusher', 'transitionGateway', 'callveyor.dialer.ready', 'callveyor.dialer.hold', 'callveyor.dialer.active', 'callveyor.dialer.wrap', 'callveyor.dialer.stop', 'survey', 'callveyor.contact', 'callveyor.call_flow', 'idTransition', 'idCacheFactories']);

  dialer.config([
    '$stateProvider', function($stateProvider) {
      return $stateProvider.state('dialer', {
        abstract: true,
        templateUrl: '/callveyor/dialer/dialer.tpl.html',
        resolve: {
          callStation: function($http) {
            return $http.post('/call_center/api/call_station.json');
          }
        },
        controller: 'DialerCtrl'
      });
    }
  ]);

  dialer.controller('DialerCtrl', [
    '$rootScope', 'Pusher', 'idCallFlow', 'transitionValidator', 'callStation', 'CallStationCache', function($rootScope, Pusher, idCallFlow, transitionValidator, callStation, CallStationCache) {
      var channel, data;
      data = callStation.data;
      CallStationCache.put('caller', data.caller);
      CallStationCache.put('campaign', data.campaign);
      CallStationCache.put('call_station', data.call_station);
      channel = data.caller.session_key;
      transitionValidator.start();
      Pusher.subscribe(channel, 'start_calling', idCallFlow.startCalling);
      Pusher.subscribe(channel, 'conference_started', idCallFlow.conferenceStarted);
      Pusher.subscribe(channel, 'caller_connected_dialer', idCallFlow.callerConnectedDialer);
      Pusher.subscribe(channel, 'caller_reassigned', idCallFlow.callerReassigned);
      Pusher.subscribe(channel, 'calling_voter', idCallFlow.callingVoter);
      Pusher.subscribe(channel, 'voter_connected', idCallFlow.voterConnected);
      Pusher.subscribe(channel, 'voter_connected_dialer', idCallFlow.voterConnectedDialer);
      Pusher.subscribe(channel, 'voter_disconnected', idCallFlow.voterDisconnected);
      Pusher.subscribe(channel, 'caller_disconnected', idCallFlow.callerDisconnected);
      Pusher.subscribe(channel, 'transfer_busy', idCallFlow.transferBusy);
      Pusher.subscribe(channel, 'transfer_connected', idCallFlow.transferConnected);
      Pusher.subscribe(channel, 'transfer_conference_ended', idCallFlow.transferConferenceEnded);
      Pusher.subscribe(channel, 'contact_joined_transfer_conference', idCallFlow.contactJoinedTransferConference);
      Pusher.subscribe(channel, 'caller_joined_transfer_conference', idCallFlow.callerJoinedTransferConference);
      Pusher.subscribe(channel, 'caller_kicked_off', idCallFlow.callerKickedOff);
      Pusher.subscribe(channel, 'caller_wrapup_voice_hit', idCallFlow.callerWrapupVoiceHit);
      return Pusher.subscribe(channel, 'call_ended', idCallFlow.callEnded);
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=dialer.js.map
*/
(function() {
  'strict';
  var contact;

  contact = angular.module('callveyor.contact', ['idCacheFactories']);

  contact.controller('ContactCtrl', [
    '$rootScope', '$scope', '$state', '$http', 'ContactCache', function($rootScope, $scope, $state, $http, ContactCache) {
      var handleStateChange, updateFromCache;
      contact = {};
      contact.data = ContactCache.get('data');
      handleStateChange = function(event, toState, toParams, fromState, fromParams) {
        switch (toState.name) {
          case 'dialer.stop':
          case 'dialer.ready':
            return contact.data = {};
        }
      };
      updateFromCache = function() {
        return contact.data = ContactCache.get('data');
      };
      $rootScope.$on('contact:changed', updateFromCache);
      $rootScope.$on('$stateChangeSuccess', handleStateChange);
      return $scope.contact = contact;
    }
  ]);

  contact.directive('idContact', function() {
    return {
      restrict: 'A',
      templateUrl: '/callveyor/dialer/contact/info.tpl.html'
    };
  });

}).call(this);

/*
//@ sourceMappingURL=contact.js.map
*/
(function() {
  'use strict';
  var surveyForm;

  surveyForm = angular.module('survey', ['ui.router', 'angularSpinner', 'idFlash', 'idCacheFactories']);

  surveyForm.factory('SurveyFormFieldsFactory', [
    '$http', '$filter', '$sce', function($http, $filter, $sce) {
      var fields;
      return fields = {
        data: {},
        prepareSurveyForm: function(payload) {
          var normalizeObj, normalizeSurvey, normalizedSurvey, selectNonEmpty;
          selectNonEmpty = function(val) {
            return val != null;
          };
          normalizeObj = function(object, type) {
            var obj;
            obj = {
              id: object.id,
              order: object.script_order,
              type: '',
              content: ''
            };
            switch (type) {
              case 'notes':
                obj.type = 'note';
                obj.content = object.note;
                break;
              case 'script_texts':
                obj.type = 'scriptText';
                obj.content = $sce.trustAsHtml(object.markdown_content);
                break;
              case 'questions':
                obj.type = 'question';
                obj.content = object.text;
                obj.possibleResponses = $filter('filter')(object.possible_responses, selectNonEmpty);
            }
            return obj;
          };
          normalizedSurvey = [];
          normalizeSurvey = function(arr, type) {
            switch (type) {
              case 'notes':
              case 'script_texts':
              case 'questions':
                return angular.forEach(arr, function(obj) {
                  return normalizedSurvey.push(normalizeObj(obj, type));
                });
            }
          };
          angular.forEach(payload.data, function(obj, type) {
            return normalizeSurvey(obj, type);
          });
          return fields.data = $filter('orderBy')(normalizedSurvey, 'order');
        },
        fetch: function() {
          return $http.get('/call_center/api/survey_fields.json');
        }
      };
    }
  ]);

  surveyForm.controller('SurveyFormCtrl', [
    '$rootScope', '$scope', '$filter', '$state', '$http', 'TransferCache', 'CallCache', 'TwilioCache', 'usSpinnerService', '$timeout', 'SurveyFormFieldsFactory', 'idFlashFactory', 'SurveyCache', function($rootScope, $scope, $filter, $state, $http, TransferCache, CallCache, TwilioCache, usSpinnerService, $timeout, SurveyFormFieldsFactory, idFlashFactory, SurveyCache) {
      var cacheTransferList, fetchErr, handleStateChange, loadForm, prepForm, requestInProgress, survey;
      survey = {
        hideButtons: true
      };
      cacheTransferList = function(payload) {
        var list;
        list = payload.data.transfers;
        return TransferCache.put('list', list);
      };
      fetchErr = function(e) {
        ErrorCache.put('SurveyFormFieldsFactory.fetch.failed', e);
        return idFlashFactory.now('danger', 'Survey failed to load. Please refresh the page to try again.');
      };
      prepForm = function(payload) {
        SurveyFormFieldsFactory.prepareSurveyForm(payload);
        survey.form = SurveyFormFieldsFactory.data;
        cacheTransferList(payload);
        return $rootScope.$broadcast('survey:load:success');
      };
      loadForm = function() {
        return SurveyFormFieldsFactory.fetch().then(prepForm, fetchErr);
      };
      handleStateChange = function(event, toState, toParams, fromState, fromParams) {
        switch (toState.name) {
          case 'dialer.wrap':
            return survey.hideButtons = false;
          default:
            return survey.hideButtons = true;
        }
      };
      $rootScope.$on('$stateChangeSuccess', handleStateChange);
      survey.responses = {
        notes: {},
        question: {}
      };
      requestInProgress = false;
      survey.save = function($event, andContinue) {
        var action, always, call_id, error, reset, success, successRan;
        if (requestInProgress) {
          console.log('survey.requestInProgress, returning');
          return;
        }
        call_id = CallCache.get('id');
        if (call_id == null) {
          ErrorCache.put('survey.save.failed', "CallCache had no ID.");
          idFlashFactory.now('danger', 'You found a bug! Please Report problem and we will have you up and running ASAP.');
          return;
        }
        usSpinnerService.spin('global-spinner');
        action = 'submit_result';
        if (!andContinue) {
          action += '_and_stop';
          TwilioCache.put('disconnect_pending', 1);
        }
        successRan = false;
        success = function(resp) {
          reset();
          $rootScope.$broadcast('survey:save:success', {
            andContinue: andContinue
          });
          return successRan = true;
        };
        error = function(resp) {
          var msg;
          msg = '';
          switch (resp.status) {
            case 400:
              msg += 'Bad request. Try again and Report problem if error continues.';
              break;
            case 408:
            case 504:
              msg += 'Browser took too long sending data. Verify internet connection and try again. Report problem if the error continues.';
              break;
            case 500:
              msg += 'Server error. We have been notified and will update account holders soon. Report problem then Stop calling.';
              break;
            case 503:
              msg += 'Minor maintenance in-progress. Try again in a minute or so. Report problem if the error continues.';
              break;
            default:
              msg += 'Please try again and Report problem if the error continues.';
          }
          idFlashFactory.now('danger', msg);
          return $rootScope.transitionInProgress = false;
        };
        always = function(resp) {
          requestInProgress = false;
          if (andContinue && successRan) {
            usSpinnerService.spin('global-spinner');
          } else {
            usSpinnerService.stop('global-spinner');
            $rootScope.transitionInProgress = false;
          }
          return $rootScope.$broadcast('survey:save:done', {
            andContinue: andContinue
          });
        };
        requestInProgress = true;
        $rootScope.transitionInProgress = true;
        $http.post("/call_center/api/" + call_id + "/" + action, survey.responses).then(success, error)["finally"](always);
        return reset = function() {
          return survey.responses = {
            notes: {},
            question: {}
          };
        };
      };
      if (!SurveyCache.get('eventsBound')) {
        $rootScope.$on('survey:save:click', survey.save);
        $rootScope.$on('survey:reload', loadForm);
        SurveyCache.put('eventsBound', true);
      }
      loadForm();
      return $scope.survey || ($scope.survey = survey);
    }
  ]);

  surveyForm.directive('idSurvey', function() {
    return {
      restrict: 'A',
      templateUrl: '/callveyor/survey/survey.tpl.html',
      controller: 'SurveyFormCtrl'
    };
  });

}).call(this);

/*
//@ sourceMappingURL=survey.js.map
*/
(function() {
  'use strict';
  var ready;

  ready = angular.module('callveyor.dialer.ready', ['ui.router', 'ui.bootstrap', 'idTwilioConnectionHandlers', 'idFlash', 'idCacheFactories']);

  ready.config([
    '$stateProvider', function($stateProvider) {
      return $stateProvider.state('dialer.ready', {
        views: {
          callFlowButtons: {
            templateUrl: '/callveyor/dialer/ready/callFlowButtons.tpl.html',
            controller: 'ReadyCtrl.splash'
          }
        }
      });
    }
  ]);

  ready.controller('ReadyCtrl.splashModal', [
    '$scope', '$state', '$modalInstance', 'CallStationCache', 'idTwilioConnectionFactory', 'idFlashFactory', 'idTransitionPrevented', function($scope, $state, $modalInstance, CallStationCache, idTwilioConnectionFactory, idFlashFactory, idTransitionPrevented) {
      var closeModalTrigger, config, twilioParams,
        _this = this;
      config = {
        caller: CallStationCache.get('caller'),
        campaign: CallStationCache.get('campaign'),
        call_station: CallStationCache.get('call_station')
      };
      twilioParams = {
        'PhoneNumber': config.call_station.phone_number,
        'campaign_id': config.campaign.id,
        'caller_id': config.caller.id,
        'session_key': config.caller.session_key
      };
      closeModalTrigger = $scope.$on("" + config.caller.session_key + ":start_calling", function() {
        return $modalInstance.close();
      });
      idTwilioConnectionFactory.afterConnected = function() {
        var p;
        p = $state.go('dialer.hold');
        return p["catch"](idTransitionPrevented);
      };
      idTwilioConnectionFactory.afterError = function() {
        var p;
        p = $state.go('dialer.ready');
        return p["catch"](idTransitionPrevented);
      };
      ready = config || {};
      ready.startCalling = function() {
        closeModalTrigger();
        $scope.transitionInProgress = true;
        idTwilioConnectionFactory.connect(twilioParams);
        return $modalInstance.close();
      };
      return $scope.ready = ready;
    }
  ]);

  ready.controller('ReadyCtrl.splash', [
    '$scope', '$rootScope', '$modal', '$window', 'idTwilioService', 'usSpinnerService', function($scope, $rootScope, $modal, $window, idTwilioService, usSpinnerService) {
      var done, err, splash;
      done = function() {
        return $rootScope.transitionInProgress = false;
      };
      err = function() {
        done();
        throw Error("TwilioClient failed to load");
      };
      idTwilioService.then(done, err);
      splash = {};
      splash.getStarted = function() {
        var openModal;
        return openModal = $modal.open({
          templateUrl: '/callveyor/dialer/ready/splash.tpl.html',
          controller: 'ReadyCtrl.splashModal',
          size: 'lg'
        });
      };
      return $scope.splash = splash;
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=ready.js.map
*/
(function() {
  'use strict';
  var hold;

  hold = angular.module('callveyor.dialer.hold', ['ui.router', 'idCacheFactories']);

  hold.config([
    '$stateProvider', function($stateProvider) {
      return $stateProvider.state('dialer.hold', {
        views: {
          callFlowButtons: {
            templateUrl: "/callveyor/dialer/hold/callFlowButtons.tpl.html",
            controller: 'HoldCtrl.buttons'
          },
          callStatus: {
            templateUrl: '/callveyor/dialer/hold/callStatus.tpl.html',
            controller: 'HoldCtrl.status'
          }
        }
      });
    }
  ]);

  hold.controller('HoldCtrl.buttons', [
    '$scope', '$state', '$timeout', '$cacheFactory', 'callStation', 'ContactCache', 'idHttpDialerFactory', 'idFlashFactory', 'usSpinnerService', function($scope, $state, $timeout, $cacheFactory, callStation, ContactCache, idHttpDialerFactory, idFlashFactory, usSpinnerService) {
      var holdCache;
      holdCache = $cacheFactory.get('hold') || $cacheFactory('hold');
      hold = holdCache.get('sharedScope');
      if (hold == null) {
        hold = {};
        holdCache.put('sharedScope', hold);
      }
      hold.campaign = callStation.data.campaign;
      hold.stopCalling = function() {
        return $state.go('dialer.stop');
      };
      hold.reset = function() {
        hold.callStatusText = 'Waiting to dial...';
        return $scope.transitionInProgress = false;
      };
      hold.dial = function() {
        var caller, contact, params;
        params = {};
        contact = (ContactCache.get('data') || {}).fields;
        caller = callStation.data.caller || {};
        params.session_id = caller.session_id;
        params.voter_id = contact.id;
        idHttpDialerFactory.dialContact(caller.id, params);
        hold.callStatusText = 'Dialing...';
        return $scope.transitionInProgress = true;
      };
      hold.skip = function() {
        var always, caller, contact, params, promise, skipErr, skipSuccess;
        params = {};
        contact = (ContactCache.get('data') || {}).fields;
        caller = callStation.data.caller || {};
        params.session_id = caller.session_id;
        params.voter_id = contact.id;
        hold.callStatusText = 'Skipping...';
        $scope.transitionInProgress = true;
        promise = idHttpDialerFactory.skipContact(caller.id, params);
        skipSuccess = function(payload) {
          ContactCache.put('data', payload.data);
          hold.callStatusText = 'Waiting to dial...';
          return $scope.$emit('contact:changed');
        };
        skipErr = function(errObj) {
          $scope.transitionInProgress = false;
          hold.callStatusText = 'Error skipping.';
          return usSpinnerService.stop('global-spinner');
        };
        always = function() {
          $scope.transitionInProgress = false;
          return usSpinnerService.stop('global-spinner');
        };
        return promise.then(skipSuccess, skipErr)["finally"](always);
      };
      return $scope.hold || ($scope.hold = hold);
    }
  ]);

  hold.controller('HoldCtrl.status', [
    '$scope', '$cacheFactory', 'callStation', function($scope, $cacheFactory, callStation) {
      var holdCache;
      holdCache = $cacheFactory.get('hold') || $cacheFactory('hold');
      hold = holdCache.get('sharedScope');
      if (hold == null) {
        hold = {};
        holdCache.put('sharedScope', hold);
      }
      hold.callStatusText = (function() {
        switch (callStation.data.campaign.type) {
          case 'Power':
          case 'Predictive':
            return 'Dialing...';
          case 'Preview':
            return 'Waiting to dial...';
        }
      })();
      return $scope.hold = hold;
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=hold.js.map
*/
(function() {
  'use strict';
  var active;

  active = angular.module('callveyor.dialer.active', ['ui.router', 'callveyor.dialer.active.transfer', 'idFlash', 'idCacheFactories', 'callveyor.http_dialer']);

  active.config([
    '$stateProvider', function($stateProvider) {
      return $stateProvider.state('dialer.active', {
        views: {
          callFlowButtons: {
            templateUrl: '/callveyor/dialer/active/callFlowButtons.tpl.html',
            controller: 'ActiveCtrl.buttons'
          },
          callStatus: {
            templateUrl: '/callveyor/dialer/active/callStatus.tpl.html',
            controller: 'ActiveCtrl.status'
          },
          callFlowDropdown: {
            templateUrl: '/callveyor/dialer/active/transfer/dropdown.tpl.html',
            controller: 'TransferCtrl.list'
          },
          transferContainer: {
            templateUrl: '/callveyor/dialer/active/transfer/container.tpl.html',
            controller: 'TransferCtrl.container'
          }
        }
      });
    }
  ]);

  active.controller('ActiveCtrl.status', [function() {}]);

  active.controller('ActiveCtrl.buttons', [
    '$scope', '$state', '$http', 'CallCache', 'TransferCache', 'CallStationCache', 'idFlashFactory', 'idHttpDialerFactory', function($scope, $state, $http, CallCache, TransferCache, CallStationCache, idFlashFactory, idHttpDialerFactory) {
      active = {};
      active.hangup = function() {
        var call_id, caller, error, promise, success, transfer;
        $scope.transitionInProgress = true;
        call_id = CallCache.get('id');
        transfer = TransferCache.get('selected');
        caller = CallStationCache.get('caller');
        promise = idHttpDialerFactory.hangup(call_id, transfer, caller);
        success = function() {
          var e, statePromise;
          e = function(obj) {
            return console.log('error transitioning to dialer.wrap', obj);
          };
          statePromise = $state.go('dialer.wrap');
          return statePromise["catch"](e);
        };
        error = function(resp) {
          console.log('error trying to stop calling', resp);
          return idFlashFactory.now('danger', 'Error. Try again.');
        };
        return promise.then(success, error);
      };
      return $scope.active = active;
    }
  ]);

  active.controller('TransferCtrl.container', [
    '$rootScope', '$scope', function($rootScope, $scope) {
      return $rootScope.rootTransferCollapse = false;
    }
  ]);

  active.controller('TransferCtrl.list', [
    '$scope', '$state', '$filter', 'TransferCache', 'idFlashFactory', function($scope, $state, $filter, TransferCache, idFlashFactory) {
      var transfer;
      transfer = {};
      transfer.cache = TransferCache;
      if (transfer.cache != null) {
        transfer.list = transfer.cache.get('list') || [];
      } else {
        transfer.list = [];
        console.log('report the problem');
      }
      transfer.select = function(id) {
        var c, e, matchingID, p, s, targets;
        matchingID = function(obj) {
          return id === obj.id;
        };
        targets = $filter('filter')(transfer.list, matchingID);
        if (targets[0] != null) {
          transfer.cache.put('selected', targets[0]);
          if ($state.is('dialer.active.transfer.selected')) {
            p = $state.go('dialer.active.transfer.reselect');
          } else {
            p = $state.go('dialer.active.transfer.selected');
          }
          s = function(r) {
            return console.log('success', r.stack, r.message);
          };
          e = function(r) {
            return console.log('error', r.stack, r.message);
          };
          c = function(r) {
            return console.log('notify', r.stack, r.message);
          };
          return p.then(s, e, c);
        } else {
          return idFlashFactory.now('danger', 'Error loading selected transfer. Please try again and Report problem if error continues.');
        }
      };
      return $scope.transfer = transfer;
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=active.js.map
*/
(function() {
  'use strict';
  var transfer;

  transfer = angular.module('callveyor.dialer.active.transfer', ['ui.router', 'callveyor.http_dialer', 'idCacheFactories', 'angularSpinner']);

  transfer.config([
    '$stateProvider', function($stateProvider) {
      $stateProvider.state('dialer.active.transfer', {
        abstract: true,
        views: {
          transferPanel: {
            templateUrl: '/callveyor/dialer/active/transfer/panel.tpl.html',
            controller: 'TransferPanelCtrl'
          }
        }
      });
      $stateProvider.state('dialer.active.transfer.selected', {
        views: {
          transferButtons: {
            templateUrl: '/callveyor/dialer/active/transfer/selected/buttons.tpl.html',
            controller: 'TransferButtonCtrl.selected'
          },
          transferInfo: {
            templateUrl: '/callveyor/dialer/active/transfer/info.tpl.html',
            controller: 'TransferInfoCtrl'
          }
        }
      });
      $stateProvider.state('dialer.active.transfer.reselect', {
        views: {
          transferButtons: {
            templateUrl: '/callveyor/dialer/active/transfer/selected/buttons.tpl.html',
            controller: 'TransferButtonCtrl.selected'
          },
          transferInfo: {
            templateUrl: '/callveyor/dialer/active/transfer/info.tpl.html',
            controller: 'TransferInfoCtrl'
          }
        }
      });
      return $stateProvider.state('dialer.active.transfer.conference', {
        views: {
          transferInfo: {
            templateUrl: '/callveyor/dialer/active/transfer/info.tpl.html',
            controller: 'TransferInfoCtrl'
          },
          transferButtons: {
            templateUrl: '/callveyor/dialer/active/transfer/conference/buttons.tpl.html',
            controller: 'TransferButtonCtrl.conference'
          }
        }
      });
    }
  ]);

  transfer.controller('TransferPanelCtrl', [
    '$rootScope', '$scope', '$cacheFactory', function($rootScope, $scope, $cacheFactory) {
      return $rootScope.transferStatus = 'Ready to dial...';
    }
  ]);

  transfer.controller('TransferInfoCtrl', [
    '$scope', 'TransferCache', function($scope, TransferCache) {
      transfer = TransferCache.get('selected');
      return $scope.transfer = transfer;
    }
  ]);

  transfer.factory('TransferDialerEventFactory', [
    '$rootScope', 'usSpinnerService', function($rootScope, usSpinnerService) {
      var handlers;
      handlers = {
        httpSuccess: function($event, resp) {
          console.log('http dialer success', resp);
          return $rootScope.transferStatus = resp.data.status;
        },
        httpError: function($event, resp) {
          console.log('http dialer error', resp);
          usSpinnerService.stop('transfer-spinner');
          $rootScope.transitionInProgress = false;
          return $rootScope.transferStatus = 'Dial failed.';
        }
      };
      $rootScope.$on('http_dialer:success', handlers.httpSuccess);
      $rootScope.$on('http_dialer:error', handlers.httpError);
      return handlers;
    }
  ]);

  transfer.controller('TransferButtonCtrl.selected', [
    '$rootScope', '$scope', '$state', 'TransferCache', 'TransferDialerEventFactory', 'CallCache', 'ContactCache', 'idHttpDialerFactory', 'usSpinnerService', 'CallStationCache', function($rootScope, $scope, $state, TransferCache, TransferDialerEventFactory, CallCache, ContactCache, idHttpDialerFactory, usSpinnerService, CallStationCache) {
      var isWarmTransfer, selected, transfer_type;
      transfer = {};
      transfer.cache = TransferCache;
      selected = transfer.cache.get('selected');
      transfer_type = selected.transfer_type;
      isWarmTransfer = function() {
        return transfer_type === 'warm';
      };
      transfer.dial = function() {
        var caller, contact, params;
        params = {};
        contact = (ContactCache.get('data') || {}).fields;
        caller = CallStationCache.get('caller');
        params.voter = contact.id;
        params.call = CallCache.get('id');
        params.caller_session = caller.session_id;
        params.transfer = {
          id: selected.id
        };
        $rootScope.transferStatus = 'Preparing to dial...';
        idHttpDialerFactory.dialTransfer(params);
        $rootScope.transitionInProgress = true;
        return usSpinnerService.spin('transfer-spinner');
      };
      transfer.cancel = function() {
        TransferCache.remove('selected');
        return $state.go('dialer.active');
      };
      $rootScope.rootTransferCollapse = false;
      return $scope.transfer = transfer;
    }
  ]);

  transfer.controller('TransferButtonCtrl.conference', [
    '$rootScope', '$scope', '$state', '$http', 'TransferCache', 'CallStationCache', 'idHttpDialerFactory', 'usSpinnerService', 'idFlashFactory', function($rootScope, $scope, $state, $http, TransferCache, CallStationCache, idHttpDialerFactory, usSpinnerService, idFlashFactory) {
      transfer = {};
      transfer.cache = TransferCache;
      usSpinnerService.stop('transfer-spinner');
      $rootScope.transferStatus = 'Transfer on call';
      transfer.hangup = function() {
        var caller, error, promise;
        caller = CallStationCache.get('caller');
        promise = idHttpDialerFactory.hangupTransfer(caller);
        error = function(resp) {
          return $rootScope.transferStatus = "Transfer on call (hangup failed)";
        };
        return promise["catch"](error);
      };
      return $scope.transfer = transfer;
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=transfer.js.map
*/
(function() {
  'use strict';
  var wrap;

  wrap = angular.module('callveyor.dialer.wrap', []);

  wrap.config([
    '$stateProvider', function($stateProvider) {
      return $stateProvider.state('dialer.wrap', {
        views: {
          callStatus: {
            templateUrl: '/callveyor/dialer/wrap/callStatus.tpl.html',
            controller: 'WrapCtrl.status'
          },
          callFlowButtons: {
            templateUrl: '/callveyor/dialer/wrap/callFlowButtons.tpl.html',
            controller: 'WrapCtrl.buttons'
          }
        }
      });
    }
  ]);

  wrap.controller('WrapCtrl.status', [
    '$rootScope', '$scope', function($rootScope, $scope) {
      var doneStatus, saveSuccess, successStatus;
      wrap = {};
      wrap.status = 'Waiting for call results.';
      saveSuccess = false;
      successStatus = function() {
        saveSuccess = true;
        return wrap.status = 'Results saved.';
      };
      doneStatus = function() {
        if (saveSuccess) {
          wrap.status = "Results saved. Waiting for next contact from server.";
        } else {
          wrap.status = "Results failed to save.";
        }
        return saveSuccess = false;
      };
      $rootScope.$on('survey:save:success', successStatus);
      $rootScope.$on('survey:save:done', doneStatus);
      return $scope.wrap = wrap;
    }
  ]);

  wrap.controller('WrapCtrl.buttons', [function() {}]);

}).call(this);

/*
//@ sourceMappingURL=wrap.js.map
*/
(function() {
  'use strict';
  var stop;

  stop = angular.module('callveyor.dialer.stop', ['ui.router', 'idCacheFactories']);

  stop.config([
    '$stateProvider', function($stateProvider) {
      return $stateProvider.state('dialer.stop', {
        views: {
          callFlowButtons: {
            templateUrl: "/callveyor/dialer/stop/callFlowButtons.tpl.html",
            controller: 'StopCtrl.buttons'
          },
          callStatus: {
            templateUrl: '/callveyor/dialer/stop/callStatus.tpl.html',
            controller: 'StopCtrl.status'
          }
        }
      });
    }
  ]);

  stop.controller('StopCtrl.buttons', [
    '$scope', '$state', 'TwilioCache', '$http', 'idTwilioService', 'callStation', function($scope, $state, TwilioCache, $http, idTwilioService, callStation) {
      var always, caller_id, connection, params, stopPromise, whenDisconnected;
      connection = TwilioCache.get('connection');
      caller_id = callStation.data.caller.id;
      params = {};
      params.session_id = callStation.data.caller.session_id;
      stopPromise = $http.post("/call_center/api/" + caller_id + "/stop_calling", params);
      whenDisconnected = function() {
        var p;
        p = $state.go('dialer.ready');
        return p["catch"](idTransitionPrevented);
      };
      always = function() {
        connection.disconnect(whenDisconnected);
        connection.disconnect();
        return $state.go('dialer.ready');
      };
      return stopPromise["finally"](always);
    }
  ]);

  stop.controller('StopCtrl.status', [
    '$scope', function($scope) {
      stop = {};
      stop.callStatusText = 'Stopping...';
      return $scope.stop = stop;
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=stop.js.map
*/
angular.module('callveyor.dialer').run(['$templateCache', function($templateCache) {
  'use strict';

  $templateCache.put('/callveyor/dialer/dialer.tpl.html',
    "<!-- Fixed top nav --><nav class=\"navbar navbar-default navbar-fixed-top\" role=\"navigation\" data-ng-cloak=\"\"><div class=\"container-fluid\"><div class=\"row\"><div class=\"col-xs-6\"><span data-us-spinner=\"{lines:5,width:5,radius:5,corners:1.0,trail:10,length:0,top:13,left:-6,rotate:56,color:'#30475f'}\" data-spinner-key=\"global-spinner\"></span> <!-- callStatus ui-view --><div class=\"navbar-left status\"><div data-ui-view=\"callStatus\"><p class=\"navbar-text label label-info\"></p></div></div><!-- /callStatus ui-view --></div><div class=\"col-xs-6\"><!-- callFlowButtons ui-view --><div class=\"navbar-right\"><ul class=\"nav navbar-nav add-gutter\"><li class=\"dropdown\" data-ui-view=\"callFlowDropdown\"></li><li data-ui-view=\"callFlowButtons\"></li></ul></div><!-- /callFlowButtons ui-view --></div></div><div class=\"row border-top-thin\" data-ui-view=\"transferContainer\"></div></div></nav><!-- /Fixed top nav --><!-- callInPhone ui-view --><div class=\"call-in-phone\" data-ui-view=\"callInPhone\"></div><!-- /callInPhone ui-view -->"
  );


  $templateCache.put('/callveyor/dialer/hold/callFlowButtons.tpl.html',
    "<button class=\"btn btn-primary navbar-btn\" data-ng-click=\"hold.stopCalling()\" data-ng-disabled=\"transitionInProgress\">Stop calling</button> <button class=\"btn btn-primary navbar-btn\" data-ng-click=\"hold.skip()\" data-ng-if=\"hold.campaign.type == 'Preview'\" data-ng-disabled=\"transitionInProgress\">Skip</button> <button class=\"btn btn-primary navbar-btn\" data-ng-click=\"hold.dial()\" data-ng-if=\"hold.campaign.type == 'Preview'\" data-ng-disabled=\"transitionInProgress\">Dial</button>"
  );


  $templateCache.put('/callveyor/dialer/hold/callStatus.tpl.html',
    "<span class=\"navbar-text label label-info\">{{hold.callStatusText}}</span>"
  );


  $templateCache.put('/callveyor/dialer/ready/callFlowButtons.tpl.html',
    "<button class=\"btn btn-primary navbar-btn\" data-ng-click=\"splash.getStarted()\">Start</button> <span data-id-logout=\"\"></span>"
  );


  $templateCache.put('/callveyor/dialer/ready/callInPhone.tpl.html',
    "<p><b>Dial-in number:</b> {{ready.call_station.phone_number}} <b>PIN:</b> {{ready.caller.pin}}</p>"
  );


  $templateCache.put('/callveyor/dialer/ready/callStatus.tpl.html',
    "<span class=\"navbar-text label label-info\">Start calling or Dial-in to begin.</span>"
  );


  $templateCache.put('/callveyor/dialer/ready/contactInfo.tpl.html',
    "<p>Contact details will be listed here when available...</p>"
  );


  $templateCache.put('/callveyor/dialer/ready/splash.tpl.html',
    "<div class=\"modal-header\"><h3 class=\"modal-title\">Choose your path</h3></div><div class=\"modal-body\"><div class=\"container-fluid\"><div class=\"row\"><div class=\"col-sm-6\"><h4>Other Phone</h4><p><b>Dial:</b> {{ready.call_station.phone_number}}</p><p><b>PIN:</b> {{ready.caller.pin}}</p><p><b>Dial</b> the above number from a cell or landline then key in your <b>PIN</b> when prompted.</p></div><div class=\"col-sm-6\"><h4>Browser Phone</h4><div class=\"btn-group btn-group-justified\"><div class=\"btn-group\"><button class=\"btn btn-primary navbar-btn\" data-ng-click=\"ready.startCalling()\" data-ng-disabled=\"transitionInProgress\">Start calling</button></div></div><div class=\"alert alert-info\"><p>Pre-flight checks<ol class=\"bump-left\"><li>Computer has a built-in microphone or a headset is plugged in</li><li>Internet speed received a 'B' or better from <a href=\"http://pingtest.net/\" target=\"_blank\">pingtest.net</a></li><li>Firewall(s) allow Voice over IP (VoIP) connections. Some firewalls call this 'Skype'. <a href=\"https://impactdialing.freshdesk.com/support/solutions/articles/1000016223-troubleshooting-call-quality\" target=\"_blank\">Read more...</a></li></ol></p></div><p class=\"alert alert-warning\"><em>Poor voice quality, dropped calls or connecting/disconnecting calls rapidly are symptoms of a mis-configured firewall or poor network conditions. Try the Other Phone path.</em></p></div></div></div></div>"
  );


  $templateCache.put('/callveyor/dialer/stop/callFlowButtons.tpl.html',
    ""
  );


  $templateCache.put('/callveyor/dialer/stop/callStatus.tpl.html',
    "<p class=\"navbar-text label label-info\">{{stop.callStatusText}}</p>"
  );


  $templateCache.put('/callveyor/dialer/wrap/callFlowButtons.tpl.html',
    "<div data-ng-hide=\"survey.hideButtons\"><button class=\"btn btn-primary navbar-btn\" data-ng-click=\"$emit('survey:save:click', false)\" data-ng-disabled=\"transitionInProgress\">Save &amp; stop calling</button> <button class=\"btn btn-primary navbar-btn\" data-ng-click=\"$emit('survey:save:click', true)\" data-ng-disabled=\"transitionInProgress\">Save &amp; continue</button></div>"
  );


  $templateCache.put('/callveyor/dialer/wrap/callStatus.tpl.html',
    "<span class=\"navbar-text label label-info\">{{wrap.status}}</span>"
  );


  $templateCache.put('/callveyor/dialer/active/callFlowButtons.tpl.html',
    "<button class=\"btn btn-primary navbar-btn\" data-ng-click=\"active.hangup()\" data-ng-disabled=\"transitionInProgress\">Hangup</button>"
  );


  $templateCache.put('/callveyor/dialer/active/callStatus.tpl.html',
    "<span class=\"navbar-text label label-info\">Contact on call</span>"
  );


  $templateCache.put('/callveyor/dialer/active/transfer/conference/buttons.tpl.html',
    "<button class=\"btn btn-primary navbar-btn\" data-ng-click=\"transfer.hangup()\" data-ng-disabled=\"transitionInProgress\">Hangup</button>"
  );


  $templateCache.put('/callveyor/dialer/active/transfer/container.tpl.html',
    "<div collapse=\"rootTransferCollapse\" data-ui-view=\"transferPanel\"></div>"
  );


  $templateCache.put('/callveyor/dialer/active/transfer/dropdown.tpl.html',
    "<div class=\"btn-group\"><button type=\"button\" class=\"btn btn-default navbar-btn dropdown-toggle\">Transfer <b class=\"caret\"></b></button><ul class=\"dropdown-menu\" role=\"menu\"><li data-ng-repeat=\"target in transfer.list\"><a href=\"#\" data-ng-click=\"transfer.select(target.id)\">{{target.label}} ({{target.phone_number}}) <span class=\"label label-{{target.transfer_type == 'warm' ? 'danger' : 'info'}}\">{{target.transfer_type}}</span></a></li></ul></div>"
  );


  $templateCache.put('/callveyor/dialer/active/transfer/info.tpl.html',
    "<span class=\"navbar-text\">{{transfer.label}} ({{transfer.phone_number}}) <span class=\"label label-{{transfer.transfer_type == 'warm' ? 'danger' : 'info'}}\">{{transfer.transfer_type}}</span></span>"
  );


  $templateCache.put('/callveyor/dialer/active/transfer/panel.tpl.html',
    "<div class=\"col-xs-4\"><div class=\"navbar-left status\"><span data-us-spinner=\"{lines:5,width:5,radius:5,corners:1.0,trail:10,length:0,top:13,left:-6,rotate:56,color:'#30475f'}\" data-spinner-key=\"transfer-spinner\"></span> <span class=\"label label-info navbar-text\">{{transferStatus}}</span></div></div><div class=\"col-xs-4\" data-ui-view=\"transferInfo\"></div><div class=\"col-xs-4\"><div class=\"navbar-right\" data-ui-view=\"transferButtons\"></div></div>"
  );


  $templateCache.put('/callveyor/dialer/active/transfer/selected/buttons.tpl.html',
    "<button class=\"btn btn-primary navbar-btn\" data-ng-click=\"transfer.cancel()\" data-ng-disabled=\"transitionInProgress\">Cancel</button> <button class=\"btn btn-primary navbar-btn\" data-ng-click=\"transfer.dial()\" data-ng-disabled=\"transitionInProgress\">Dial</button>"
  );

}]);

angular.module('callveyor.contact').run(['$templateCache', function($templateCache) {
  'use strict';

  $templateCache.put('/callveyor/dialer/contact/info.tpl.html',
    "<div class=\"row fixed-contact panel panel-default\"><div class=\"panel-heading\">Contact details</div><div class=\"panel-body\"><p class=\"col-xs-12\" data-ng-hide=\"contact.data.fields\">Name, phone, address, etc will be listed here when connected.</p><!-- system fields --><dl class=\"dl-horizontal col-xs-6 col-sm-12\"><dt data-ng-hide=\"!contact.data.fields.custom_id || !contact.data.ID_flag\">ID</dt><dd data-ng-hide=\"!contact.data.fields.custom_id || !contact.data.ID_flag\">{{contact.data.fields.custom_id}}</dd><dt data-ng-hide=\"!contact.data.fields.first_name || !contact.data.FirstName_flag\">First name</dt><dd data-ng-hide=\"!contact.data.fields.first_name || !contact.data.FirstName_flag\">{{contact.data.fields.first_name}}</dd><dt data-ng-hide=\"!contact.data.fields.middle_name || !contact.data.MiddleName_flag\">Middle name</dt><dd data-ng-hide=\"!contact.data.fields.middle_name || !contact.data.MiddleName_flag\">{{contact.data.fields.middle_name}}</dd><dt data-ng-hide=\"!contact.data.fields.last_name || !contact.data.LastName_flag\">Last name</dt><dd data-ng-hide=\"!contact.data.fields.last_name || !contact.data.LastName_flag\">{{contact.data.fields.last_name}}</dd><dt data-ng-hide=\"!contact.data.fields.suffix || !contact.data.Suffix_flag\">Suffix</dt><dd data-ng-hide=\"!contact.data.fields.suffix || !contact.data.Suffix_flag\">{{contact.data.fields.suffix}}</dd><dt data-ng-hide=\"!contact.data.fields.address || !contact.data.Address_flag\">Address</dt><dd data-ng-hide=\"!contact.data.fields.address || !contact.data.Address_flag\">{{contact.data.fields.address}}</dd><dt data-ng-hide=\"!contact.data.fields.city || !contact.data.City_flag\">City</dt><dd data-ng-hide=\"!contact.data.fields.city || !contact.data.City_flag\">{{contact.data.fields.city}}</dd><dt data-ng-hide=\"!contact.data.fields.state || !contact.data.State/Province_flag\">State</dt><dd data-ng-hide=\"!contact.data.fields.state || !contact.data.State/Province_flag\">{{contact.data.fields.state}}</dd><dt data-ng-hide=\"!contact.data.fields.zip_code || !contact.data.Zip/Postal_flag\">Zip / Postal code</dt><dd data-ng-hide=\"!contact.data.fields.zip_code || !contact.data.Zip/Postal_flag\">{{contact.data.fields.zip_code}}</dd><dt data-ng-hide=\"!contact.data.fields.country || !contact.data.Country_flag\">Country</dt><dd data-ng-hide=\"!contact.data.fields.country || !contact.data.Country_flag\">{{contact.data.fields.country}}</dd><dt data-ng-hide=\"!contact.data.fields.phone || !contact.data.Phone_flag\">Phone</dt><dd data-ng-hide=\"!contact.data.fields.phone || !contact.data.Phone_flag\">{{contact.data.fields.phone}}</dd><dt data-ng-hide=\"!contact.data.fields.email || !contact.data.Email_flag\">Email</dt><dd data-ng-hide=\"!contact.data.fields.email || !contact.data.Email_flag\">{{contact.data.fields.email}}</dd></dl><!-- custom fields --><dl class=\"dl-horizontal col-xs-6 col-sm-12\"><dt data-ng-repeat-start=\"(field, value) in contact.data.custom_fields\">{{field}}</dt><dd data-ng-repeat-end=\"\">{{value}}</dd></dl></div></div>"
  );

}]);

angular.module('idFlash').run(['$templateCache', function($templateCache) {
  'use strict';

  $templateCache.put('/callveyor/common/id_flash/id_flash.tpl.html',
    "<div data-alert=\"\" data-ng-repeat=\"alert in flash.alerts\" type=\"alert.type\" close=\"flash.dismiss($index)\">{{alert.message}}</div>"
  );

}]);

angular.module('survey').run(['$templateCache', function($templateCache) {
  'use strict';

  $templateCache.put('/callveyor/survey/survey.tpl.html',
    "<div class=\"col-xs-12\"><div class=\"veil\" ng-show=\"transitionInProgress\"></div><form role=\"form\"><div class=\"well\" data-ng-repeat=\"item in survey.form\"><div data-ng-if=\"item.type == 'scriptText'\" data-ng-bind-html=\"item.content\"></div><label data-ng-if=\"item.type != 'scriptText'\" for=\"item_{{item.id}}\">{{item.content}}</label><input id=\"item_{{item.id}}\" class=\"form-control\" data-ng-if=\"item.type == 'note'\" data-ng-model=\"survey.responses.notes[item.id]\"><select id=\"item_{{item.id}}\" class=\"form-control\" data-ng-if=\"item.type == 'question'\" data-ng-model=\"survey.responses.question[item.id]\"><option data-ng-repeat=\"response in item.possibleResponses\" value=\"{{response.id}}\">{{response.value}}</option></select></div></form></div>"
  );

}]);

(function() {
  'use strict';
  var dialer;

  dialer = angular.module('callveyor.dialer', ['ui.router', 'doowb.angular-pusher', 'transitionGateway', 'callveyor.dialer.ready', 'callveyor.dialer.hold', 'callveyor.dialer.active', 'callveyor.dialer.wrap', 'callveyor.dialer.stop', 'survey', 'callveyor.contact', 'callveyor.call_flow', 'idTransition']);

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
    '$rootScope', '$cacheFactory', 'Pusher', 'idCallFlow', 'transitionValidator', 'callStation', function($rootScope, $cacheFactory, Pusher, idCallFlow, transitionValidator, callStation) {
      var callStationCache, channel;
      callStationCache = $cacheFactory('callStation');
      callStationCache.put('data', callStation.data);
      channel = callStation.data.caller.session_key;
      transitionValidator.start();
      $rootScope.$on('survey:save:success', idCallFlow.survey.save.success);
      $rootScope.$on('survey:save:done', idCallFlow.survey.save.done);
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
      return Pusher.subscribe(channel, 'caller_wrapup_voice_hit', idCallFlow.callerWrapupVoiceHit);
    }
  ]);

}).call(this);

/*
//@ sourceMappingURL=dialer.js.map
*/
(function() {
  'strict';
  var contact;

  contact = angular.module('callveyor.contact', []);

  contact.controller('ContactCtrl', [
    '$rootScope', '$scope', '$state', '$http', '$cacheFactory', function($rootScope, $scope, $state, $http, $cacheFactory) {
      var handleStateChange, updateFromCache;
      console.log('ContactCtrl');
      contact = {};
      handleStateChange = function(event, toState, toParams, fromState, fromParams) {
        console.log('handleStateChange', toState, fromState);
        switch (toState.name) {
          case 'dialer.stop':
          case 'dialer.ready':
            return contact.data = {};
        }
      };
      updateFromCache = function() {
        var callStation, callStationCache, contactCache;
        callStationCache = $cacheFactory.get('callStation');
        if (callStationCache != null) {
          callStation = callStationCache.get('data');
        } else {
          callStation = {
            campaign: {}
          };
        }
        contactCache = $cacheFactory.get('contact');
        if (contactCache != null) {
          return contact.data = contactCache.get('data');
        }
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

  surveyForm = angular.module('survey', ['ui.router', 'angularSpinner', 'idFlash']);

  surveyForm.factory('SurveyFormFieldsFactory', [
    '$http', '$filter', function($http, $filter) {
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
                obj.content = object.content;
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
    '$rootScope', '$scope', '$filter', '$state', '$http', '$cacheFactory', 'usSpinnerService', '$timeout', 'SurveyFormFieldsFactory', 'idFlashFactory', function($rootScope, $scope, $filter, $state, $http, $cacheFactory, usSpinnerService, $timeout, SurveyFormFieldsFactory, idFlashFactory) {
      var c, cacheTransferList, e, handleStateChange, prepForm, survey;
      survey = {};
      cacheTransferList = function(payload) {
        var coldOnly, list, transferCache;
        transferCache = $cacheFactory.get('transfer') || $cacheFactory('transfer');
        list = payload.data.transfers;
        coldOnly = function(transfer) {
          return transfer.transfer_type === 'cold';
        };
        list = $filter('filter')(list, coldOnly);
        return transferCache.put('list', list);
      };
      e = function(r) {
        return console.log('survey load error', r.stack, r.message);
      };
      c = function(r) {
        return console.log('survey load notify', r.stack, r.message);
      };
      prepForm = function(payload) {
        SurveyFormFieldsFactory.prepareSurveyForm(payload);
        survey.form = SurveyFormFieldsFactory.data;
        return cacheTransferList(payload);
      };
      SurveyFormFieldsFactory.fetch().then(prepForm, e, c);
      handleStateChange = function(event, toState, toParams, fromState, fromParams) {
        switch (toState.name) {
          case 'dialer.wrap':
            return survey.hideButtons = false;
          default:
            survey.disable = false;
            return survey.hideButtons = true;
        }
      };
      $rootScope.$on('$stateChangeSuccess', handleStateChange);
      survey.responses = {
        notes: {},
        question: {}
      };
      survey.disable = false;
      survey.hideButtons = true;
      survey.requestInProgress = false;
      survey.save = function($event, andContinue) {
        var action, always, callCache, call_id, error, reset, success;
        if (survey.requestInProgress) {
          return;
        }
        survey.disable = true;
        callCache = $cacheFactory.get('call');
        if (callCache != null) {
          call_id = callCache.get('id');
        } else {
          idFlashFactory.now('error', 'You found a bug! Please Report problem and we will have you up and running ASAP.');
        }
        usSpinnerService.spin('global-spinner');
        action = 'submit_result';
        if (!andContinue) {
          action += '_and_stop';
        }
        success = function(resp) {
          reset();
          idFlashFactory.now('success', 'Results saved.', 4000);
          return $rootScope.$broadcast('survey:save:success', {
            andContinue: andContinue
          });
        };
        error = function(resp) {
          var msg;
          msg = 'Survey results failed to save.';
          switch (resp.status) {
            case 400:
              msg += ' The browser sent a bad request. Please try again and Report problem if error continues.';
              break;
            case 408:
            case 504:
              msg += ' The browser took too long sending the data. Verify the internet connection before trying again and Report problem if the error continues.';
              break;
            case 500:
              msg += ' Server is having some trouble. We are looking into it and will update account holders soon. Please Report problem then Stop calling.';
              break;
            case 503:
              msg += ' Server is undergoing minor maintenance. Please try again in a minute or so and Report problem if the error continues.';
              break;
            default:
              msg += ' Please try again and Report problem if the error continues.';
          }
          return idFlashFactory.now('error', msg);
        };
        always = function(resp) {
          survey.requestInProgress = false;
          usSpinnerService.stop('global-spinner');
          return $rootScope.$broadcast('survey:save:done', {
            andContinue: andContinue
          });
        };
        survey.requestInProgress = true;
        $http.post("/call_center/api/" + call_id + "/" + action, survey.responses).then(success, error)["finally"](always);
        return reset = function() {
          return survey.responses = {
            notes: {},
            question: {}
          };
        };
      };
      $rootScope.$on('survey:save:click', survey.save);
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

  ready = angular.module('callveyor.dialer.ready', ['ui.router', 'idTwilioConnectionHandlers', 'idFlash']);

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
    '$scope', '$state', '$cacheFactory', '$modalInstance', 'idTwilioConnectionFactory', 'idFlashFactory', function($scope, $state, $cacheFactory, $modalInstance, idTwilioConnectionFactory, idFlashFactory) {
      var config, twilioParams;
      config = $cacheFactory.get('callStation').get('data');
      twilioParams = {
        'PhoneNumber': config.call_station.phone_number,
        'campaign_id': config.campaign.id,
        'caller_id': config.caller.id,
        'session_key': config.caller.session_key
      };
      ready = config || {};
      ready.startCalling = function() {
        console.log('startCalling clicked', config);
        $scope.transitionInProgress = true;
        idTwilioConnectionFactory.connect(twilioParams);
        return $modalInstance.close();
      };
      return $scope.ready = ready;
    }
  ]);

  ready.controller('ReadyCtrl.splash', [
    '$scope', '$modal', function($scope, $modal) {
      var splash;
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

  hold = angular.module('callveyor.dialer.hold', ['ui.router']);

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
    '$scope', '$state', '$timeout', '$cacheFactory', 'callStation', 'idHttpDialerFactory', 'idFlashFactory', 'usSpinnerService', function($scope, $state, $timeout, $cacheFactory, callStation, idHttpDialerFactory, idFlashFactory, usSpinnerService) {
      hold = {};
      hold.campaign = callStation.data.campaign;
      hold.stopCalling = function() {
        console.log('stopCalling clicked');
        return $state.go('dialer.stop');
      };
      hold.dial = function() {
        var caller, contact, contactCache, params;
        params = {};
        contactCache = $cacheFactory.get('contact');
        contact = (contactCache.get('data') || {}).fields;
        caller = callStation.data.caller || {};
        params.session_id = caller.session_id;
        params.voter_id = contact.id;
        idHttpDialerFactory.dialContact(caller.id, params);
        $scope.transitionInProgress = true;
        return hold.callStatusText = 'Dialing...';
      };
      hold.skip = function() {
        var always, caller, contact, contactCache, params, promise, skipErr, skipSuccess;
        params = {};
        contactCache = $cacheFactory.get('contact');
        contact = (contactCache.get('data') || {}).fields;
        caller = callStation.data.caller || {};
        params.session_id = caller.session_id;
        params.voter_id = contact.id;
        hold.callStatusText = 'Skipping...';
        $scope.transitionInProgress = true;
        promise = idHttpDialerFactory.skipContact(caller.id, params);
        skipSuccess = function(payload) {
          console.log('skip success', payload);
          contactCache.put('data', payload.data);
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
    '$scope', 'callStation', function($scope, callStation) {
      hold = {};
      hold.callStatusText = (function() {
        switch (callStation.data.campaign.type) {
          case 'Power':
          case 'Predictive':
            return 'Dialing...';
          case 'Preview':
            return 'Waiting to dial...';
          default:
            return console.log('Report this problem.');
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

  active = angular.module('callveyor.dialer.active', ['ui.router', 'callveyor.dialer.active.transfer', 'idFlash']);

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
    '$scope', '$state', '$http', '$cacheFactory', 'idFlashFactory', function($scope, $state, $http, $cacheFactory, idFlashFactory) {
      console.log('ActiveCtrl', $scope.dialer);
      active = {};
      active.hangup = function() {
        var callCache, call_id, error, stopPromise, success;
        console.log('hangup clicked');
        $scope.transitionInProgress = true;
        callCache = $cacheFactory.get('call');
        call_id = callCache.get('id');
        stopPromise = $http.post("/call_center/api/" + call_id + "/hangup");
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
          return idFlashFactory.now('error', 'Error. Try again.');
        };
        return stopPromise.then(success, error);
      };
      return $scope.active = active;
    }
  ]);

  active.controller('TransferCtrl.container', [
    '$rootScope', '$scope', function($rootScope, $scope) {
      console.log('TransferCtrl.container');
      return $rootScope.rootTransferCollapse = false;
    }
  ]);

  active.controller('TransferCtrl.list', [
    '$scope', '$state', '$filter', '$cacheFactory', 'idFlashFactory', function($scope, $state, $filter, $cacheFactory, idFlashFactory) {
      var transfer;
      console.log('TransferCtrl.list', $cacheFactory.get('transfer'));
      transfer = {};
      transfer.cache = $cacheFactory.get('transfer');
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
          console.log('target', targets[0]);
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
          return idFlashFactory.now('error', 'Error loading selected transfer. Please try again and Report problem if error continues.', 5000);
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

  transfer = angular.module('callveyor.dialer.active.transfer', []);

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
      console.log('TransferPanelCtrl');
      return $rootScope.transferStatus = 'Ready to dial...';
    }
  ]);

  transfer.controller('TransferInfoCtrl', [
    '$scope', '$cacheFactory', function($scope, $cacheFactory) {
      var cache;
      console.log('TransferInfoCtrl');
      cache = $cacheFactory.get('transfer');
      transfer = cache.get('selected');
      return $scope.transfer = transfer;
    }
  ]);

  transfer.controller('TransferButtonCtrl.selected', [
    '$rootScope', '$scope', '$state', '$filter', '$cacheFactory', 'idHttpDialerFactory', 'usSpinnerService', 'callStation', function($rootScope, $scope, $state, $filter, $cacheFactory, idHttpDialerFactory, usSpinnerService, callStation) {
      var isWarmTransfer, selected, transfer_type;
      console.log('TransferButtonCtrl.selected', $cacheFactory.get('transfer').info());
      transfer = {};
      transfer.cache = $cacheFactory.get('transfer') || $cacheFactory('transfer');
      selected = transfer.cache.get('selected');
      transfer_type = selected.transfer_type;
      isWarmTransfer = function() {
        return transfer_type === 'warm';
      };
      transfer.dial = function() {
        var callCache, caller, contact, contactCache, e, p, params, s;
        console.log('dial', $scope);
        params = {};
        contactCache = $cacheFactory.get('contact');
        callCache = $cacheFactory.get('call');
        contact = (contactCache.get('data') || {}).fields;
        caller = callStation.data.caller || {};
        params.voter = contact.id;
        params.call = callCache.get('id');
        params.caller_session = caller.session_id;
        params.transfer = {
          id: selected.id
        };
        p = idHttpDialerFactory.dialTransfer(params);
        $rootScope.transferStatus = 'Dialing...';
        $rootScope.transitionInProgress = true;
        usSpinnerService.spin('transfer-spinner');
        s = function(o) {
          $rootScope.transferStatus = 'Ringing...';
          return console.log('dial success', o);
        };
        e = function(r) {
          $rootScope.transferStatus = 'Error dialing.';
          return console.log('report this problem', r);
        };
        return p.then(s, e);
      };
      transfer.cancel = function() {
        console.log('cancel');
        this.cache.remove('selected');
        return $state.go('dialer.active');
      };
      $rootScope.rootTransferCollapse = false;
      return $scope.transfer = transfer;
    }
  ]);

  transfer.controller('TransferButtonCtrl.conference', [
    '$rootScope', '$scope', '$state', '$cacheFactory', 'idHttpDialerFactory', 'usSpinnerService', function($rootScope, $scope, $state, $cacheFactory, idHttpDialerFactory, usSpinnerService) {
      console.log('TransferButtonCtrl.conference');
      transfer = {};
      transfer.cache = $cacheFactory.get('transfer') || $cacheFactory('transfer');
      usSpinnerService.stop('transfer-spinner');
      $rootScope.transferStatus = 'Transfer on call';
      transfer.hangup = function() {
        var c, e, p, s;
        console.log('transfer.hangup');
        p = $state.go('dialer.active');
        s = function(o) {
          return console.log('success', o);
        };
        e = function(r) {
          return console.log('error', e);
        };
        c = function(n) {
          return console.log('notify', n);
        };
        return p.then(s, e, c);
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

  wrap.controller('WrapCtrl.status', [function() {}]);

  wrap.controller('WrapCtrl.buttons', [function() {}]);

}).call(this);

/*
//@ sourceMappingURL=wrap.js.map
*/
(function() {
  'use strict';
  var stop;

  stop = angular.module('callveyor.dialer.stop', ['ui.router']);

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
    '$scope', '$state', '$cacheFactory', '$http', 'idTwilioService', 'callStation', function($scope, $state, $cacheFactory, $http, idTwilioService, callStation) {
      var always, caller_id, connection, params, stopPromise, _twilioCache;
      _twilioCache = $cacheFactory.get('Twilio');
      connection = _twilioCache.get('connection');
      caller_id = callStation.data.caller.id;
      params = {};
      params.session_id = callStation.data.caller.session_id;
      stopPromise = $http.post("/call_center/api/" + caller_id + "/stop_calling", params);
      always = function() {
        connection.disconnect();
        return $state.go('dialer.ready');
      };
      return stopPromise["finally"](always);
    }
  ]);

  stop.controller('StopCtrl.status', [
    '$scope', function($scope) {
      console.log('stop.callStatusCtrl', $scope);
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
    "<!-- Fixed top nav --><nav class=\"navbar navbar-default navbar-fixed-top\" role=\"navigation\"><div class=\"container-fluid\"><div class=\"row\"><div class=\"col-xs-4\"><!-- callStatus ui-view --><div class=\"navbar-left status\"><span data-us-spinner=\"{length:0,top:10,left:10,color:'#456587'}\" data-spinner-key=\"global-spinner\"></span><div class=\"call-status\" data-ui-view=\"callStatus\"><p class=\"navbar-text label label-info\"></p></div></div><!-- /callStatus ui-view --></div><div class=\"col-xs-4\"><p class=\"alert small-text\" data-ng-show=\"flash.notice || flash.warning || flash.error || flash.success\" data-ng-class=\"{'alert-info': flash.notice, 'alert-warning': flash.warning, 'alert-danger': flash.error, 'alert-success': flash.success}\">{{flash.notice || flash.warning || flash.error || flash.success}}</p></div><div class=\"col-xs-4\"><!-- callFlowButtons ui-view --><div class=\"navbar-right\"><ul class=\"nav navbar-nav\"><li class=\"dropdown\" data-ui-view=\"callFlowDropdown\"></li><li data-ui-view=\"callFlowButtons\"></li></ul></div><!-- /callFlowButtons ui-view --></div></div><div class=\"row border-top-thin\" data-ui-view=\"transferContainer\"></div></div></nav><!-- /Fixed top nav --><!-- callInPhone ui-view --><div class=\"call-in-phone\" data-ui-view=\"callInPhone\"></div><!-- /callInPhone ui-view -->"
  );


  $templateCache.put('/callveyor/dialer/hold/callFlowButtons.tpl.html',
    "<button class=\"btn btn-primary navbar-btn\" data-ng-click=\"hold.stopCalling()\" data-ng-disabled=\"transitionInProgress\">Stop calling</button> <button class=\"btn btn-primary navbar-btn\" data-ng-click=\"hold.dial()\" data-ng-if=\"hold.campaign.type == 'Preview'\" data-ng-disabled=\"transitionInProgress\">Dial</button> <button class=\"btn btn-primary navbar-btn\" data-ng-click=\"hold.skip()\" data-ng-if=\"hold.campaign.type == 'Preview'\" data-ng-disabled=\"transitionInProgress\">Skip</button>"
  );


  $templateCache.put('/callveyor/dialer/hold/callStatus.tpl.html',
    "<span class=\"navbar-text label label-info\">{{hold.callStatusText}}</span>"
  );


  $templateCache.put('/callveyor/dialer/ready/callFlowButtons.tpl.html',
    "<!-- <span class=\"small-text\">\n" +
    "  {{ready.startCallingText}}\n" +
    "</span>\n" +
    "<button class=\"btn btn-primary navbar-btn\"\n" +
    "        data-ng-click=\"ready.startCalling()\"\n" +
    "        data-ng-disabled=\"transitionInProgress\">\n" +
    "  Start calling\n" +
    "</button> --> <button class=\"btn btn-primary navbar-btn\" data-ng-click=\"splash.getStarted()\">Start</button>"
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
    "<div class=\"btn-group\" data-ng-hide=\"survey.hideButtons\"><button class=\"btn btn-primary navbar-btn\" data-ng-click=\"$emit('survey:save:click', false); transitionInProgress = true\" data-ng-disabled=\"transitionInProgress\">Save &amp; stop calling</button> <button class=\"btn btn-primary navbar-btn\" data-ng-click=\"$emit('survey:save:click', true); transitionInProgress = true;\" data-ng-disabled=\"transitionInProgress\">Save &amp; continue</button></div>"
  );


  $templateCache.put('/callveyor/dialer/wrap/callStatus.tpl.html',
    "<span class=\"navbar-text label label-info\">Waiting for call results</span>"
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
    "<a href=\"#\" class=\"dropdown-toggle\">Transfer <b class=\"caret\"></b></a><ul class=\"dropdown-menu\"><li data-ng-repeat=\"target in transfer.list\"><a href=\"#\" data-ng-click=\"transfer.select(target.id)\">{{target.label}} ({{target.phone_number}}) <span class=\"label label-{{target.transfer_type == 'warm' ? 'danger' : 'info'}}\">{{target.transfer_type}}</span></a></li></ul>"
  );


  $templateCache.put('/callveyor/dialer/active/transfer/info.tpl.html',
    "<span class=\"navbar-text\">{{transfer.label}} ({{transfer.phone_number}}) <span class=\"label label-{{transfer.transfer_type == 'warm' ? 'danger' : 'info'}}\">{{transfer.transfer_type}}</span></span>"
  );


  $templateCache.put('/callveyor/dialer/active/transfer/panel.tpl.html',
    "<div class=\"col-xs-4\"><div class=\"navbar-left status\"><span data-us-spinner=\"{length:0,top:10,left:-25,color:'#456587'}\" data-spinner-key=\"transfer-spinner\"></span> <span class=\"label label-info navbar-text\">{{transferStatus}}</span></div></div><div class=\"col-xs-4\" data-ui-view=\"transferInfo\"></div><div class=\"col-xs-4\"><div class=\"navbar-right\" data-ui-view=\"transferButtons\"></div></div>"
  );


  $templateCache.put('/callveyor/dialer/active/transfer/selected/buttons.tpl.html',
    "<button class=\"btn btn-primary navbar-btn\" data-ng-click=\"transfer.dial()\" data-ng-disabled=\"transitionInProgress\">Dial</button> <button class=\"btn btn-primary navbar-btn\" data-ng-click=\"transfer.cancel()\" data-ng-disabled=\"transitionInProgress\">Cancel</button>"
  );

}]);

angular.module('callveyor.contact').run(['$templateCache', function($templateCache) {
  'use strict';

  $templateCache.put('/callveyor/dialer/contact/info.tpl.html',
    "<div class=\"row content-box panel panel-default\"><div class=\"panel-heading\">Contact details</div><div class=\"panel-body\"><p class=\"col-xs-12\" data-ng-hide=\"contact.data.fields\">Name, phone, address, etc will be listed here when connected.</p><!-- system fields --><dl class=\"dl-horizontal col-xs-6 col-sm-12\"><dt data-ng-hide=\"!contact.data.fields.custom_id\">ID</dt><dd data-ng-hide=\"!contact.data.fields.custom_id\">{{contact.data.fields.custom_id}}</dd><dt data-ng-hide=\"!contact.data.fields.first_name\">First name</dt><dd data-ng-hide=\"!contact.data.fields.first_name\">{{contact.data.fields.first_name}}</dd><dt data-ng-hide=\"!contact.data.fields.middle_name\">Middle name</dt><dd data-ng-hide=\"!contact.data.fields.middle_name\">{{contact.data.fields.middle_name}}</dd><dt data-ng-hide=\"!contact.data.fields.last_name\">Last name</dt><dd data-ng-hide=\"!contact.data.fields.last_name\">{{contact.data.fields.last_name}}</dd><dt data-ng-hide=\"!contact.data.fields.suffix\">Suffix</dt><dd data-ng-hide=\"!contact.data.fields.suffix\">{{contact.data.fields.suffix}}</dd><dt data-ng-hide=\"!contact.data.fields.address\">Address</dt><dd data-ng-hide=\"!contact.data.fields.address\">{{contact.data.fields.address}}</dd><dt data-ng-hide=\"!contact.data.fields.city\">City</dt><dd data-ng-hide=\"!contact.data.fields.city\">{{contact.data.fields.city}}</dd><dt data-ng-hide=\"!contact.data.fields.state\">State</dt><dd data-ng-hide=\"!contact.data.fields.state\">{{contact.data.fields.state}}</dd><dt data-ng-hide=\"!contact.data.fields.zip_code\">Zip / Postal code</dt><dd data-ng-hide=\"!contact.data.fields.zip_code\">{{contact.data.fields.zip_code}}</dd><dt data-ng-hide=\"!contact.data.fields.country\">Country</dt><dd data-ng-hide=\"!contact.data.fields.country\">{{contact.data.fields.country}}</dd><dt data-ng-hide=\"!contact.data.fields.phone\">Phone</dt><dd data-ng-hide=\"!contact.data.fields.phone\">{{contact.data.fields.phone}}</dd><dt data-ng-hide=\"!contact.data.fields.email\">Email</dt><dd data-ng-hide=\"!contact.data.fields.email\">{{contact.data.fields.email}}</dd></dl><!-- custom fields --><dl class=\"dl-horizontal col-xs-6 col-sm-12\"><dt data-ng-repeat-start=\"(field, value) in contact.data.custom_fields\">{{field}}</dt><dd data-ng-repeat-end=\"\">{{value}}</dd></dl></div></div>"
  );

}]);

angular.module('survey').run(['$templateCache', function($templateCache) {
  'use strict';

  $templateCache.put('/callveyor/survey/survey.tpl.html',
    "<div class=\"col-xs-12\"><div class=\"veil\" ng-show=\"survey.disable\"></div><form role=\"form\"><div class=\"well\" data-ng-repeat=\"item in survey.form\"><pre data-ng-if=\"item.type == 'scriptText'\">{{item.content}}</pre><label data-ng-if=\"item.type != 'scriptText'\" for=\"item_{{item.id}}\">{{item.content}}</label><input id=\"item_{{item.id}}\" class=\"form-control\" data-ng-if=\"item.type == 'note'\" data-ng-model=\"survey.responses.notes[item.id]\"><select id=\"item_{{item.id}}\" class=\"form-control\" data-ng-if=\"item.type == 'question'\" data-ng-model=\"survey.responses.question[item.id]\"><option data-ng-repeat=\"response in item.possibleResponses\" value=\"{{response.id}}\">{{response.value}}</option></select></div></form></div>"
  );

}]);

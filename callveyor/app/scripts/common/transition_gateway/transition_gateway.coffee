##
# This module can be used to enforce a particular $state based workflow.
#
mod = angular.module('transitionGateway', [
  'ui.router'
])

mod.constant('validTransitions', {
  'root': ['dialer.ready'],
  'dialer.ready': ['dialer.hold'],
  'dialer.hold': ['dialer.active', 'dialer.stop'],
  'dialer.active': ['dialer.wrap', 'dialer.stop', 'dialer.active.transfer.selected', 'dialer.active.transfer.reselected', 'dialer.active.transfer.conference'],
  'dialer.active.transfer.selected': ['dialer.active', 'dialer.wrap'],
  'dialer.active.transfer.reselected': ['dialer.active', 'dialer.wrap'],
  'dialer.active.transfer.conference': ['dialer.active', 'dialer.wrap'],
  'dialer.wrap': ['dialer.hold', 'dialer.stop'],
  'dialer.stop': ['dialer.ready']
})

mod.factory('transitionValidator', [
  '$rootScope', 'validTransitions',
  ($rootScope,   validTransitions) ->
    {
      reviewTransition: (eventObj, toState, toParams, fromState, fromParams) ->
        toName   = toState.name
        fromName = fromState.name || 'root'

        entry = validTransitions[fromName]

        if !entry? || entry.indexOf(toName) == -1
          eventObj.preventDefault()

      start: ->
        if angular.isFunction(@stop)
          @stop()
        @stop = $rootScope.$on('$stateChangeStart', @reviewTransition)

      stop: ->
    }
])
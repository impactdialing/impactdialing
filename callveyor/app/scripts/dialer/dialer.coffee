'use strict'

dialer = angular.module('callveyor.dialer', [
  'callveyor.dialer.ready',
  'callveyor.dialer.hold',
  'callveyor.dialer.active',
  'callveyor.dialer.wrap',
  'callveyor.dialer.stop',
  'callveyor.dialer.survey',
  'callveyor.contact'
])

dialer.config([
  '$stateProvider',
  ($stateProvider) ->
    $stateProvider.state('dialer', {
      abstract: true
      templateUrl: '/scripts/dialer/dialer.tpl.html'
      resolve:
        callStation: ($http) -> $http.post('/call_center/api/call_station.json')
      controller: 'DialerCtrl'
    })
])

dialer.factory('CallFlowFactory', [
  '$rootScope', '$state', '$cacheFactory', 'idDialerService',
  ($rootScope,   $state,   $cacheFactory,   idDialerService) ->
    console.log 'CallFlowFactory'

    handlers = {
      ##
      # start_calling
      #
      # This event is published when the start_conf TwiML endpoint is served.
      # It is sent immediately before `conference_started` in preview or power
      # modes or `caller_connected_dialer` in predictive mode.
      #
      # Purpose: notify client that the caller is connected to the conference line.
      #
      # @param {object} {caller_session_id}
      ###
      LEGACY-way
      - set caller_session ID on campaign call model from emitted `data`
      - render caller_actions.js view
      - hide all caller action buttons
      - hide call in data
      - update caller action buttons
      ###
      startCalling: (data) ->
        callStationCache = $cacheFactory.get('callStation')
        callStation = callStationCache.get('data')
        console.log 'start_calling', callStation
        caller = callStation.caller
        caller.session_id = data.caller_session_id
      ##
      # conference_started
      #
      # This event is published immediately after `start_calling` is published.
      # It is also published each time a caller transitions from wrap-up to on-hold.
      #
      # Purpose: notify the client of new contact data.
      #
      # IMPORTANT: Event only applies to Preview & Power dialer modes.
      #
      # @param {object} {fields: Object, custom_fields: Object, {
      #                                                         phone,
      #                                                         custom_id,
      #                                                         last_name,
      #                                                         first_name,
      #                                                         middle_name,
      #                                                         suffix,
      #                                                         email,
      #                                                         address,
      #                                                         city,
      #                                                         state,
      #                                                         zip_code,
      #                                                         country
      #                                                        }}
      # Where the list of 'VOTER_DATA_COLUMNS' fields (listed last) is customized
      # by the campaign admin.
      ###
      LEGACY-way
      - unset call_id on campaign call model
      - clear & set contact (aka lead) info
      - clear script form
      - hide placeholder contact message
      - render contact info
      - update caller action buttons
      ###
      conferenceStarted: (contact) ->
        callStationCache = $cacheFactory.get('callStation')
        contactCache     = $cacheFactory.get('contact') || $cacheFactory('contact')
        callStation      = callStationCache.get('data')
        console.log 'conference_started (preview & power only)', contact, callStation
        # contactCache = $cacheFactory.get('contact') || $cacheFactory('contact')
        contactCache.put('data', contact)
        $rootScope.$broadcast('contact:changed')

        if callStation.campaign.type == 'Power'
          caller = callStation.caller
          console.log 'dialing for Power', caller
          dialing = idDialerService.dial(caller.id, {
            session_id: caller.session_id,
            voter_id: contact.id
          })
      ##
      # caller_connected_dialer
      #
      # This event is published immediately after `start_calling` is published.
      # It is also published each time a caller transitions from wrap-up to on-hold.
      # This event is sent instead of `conference_started` when in Predictive mode.
      #
      # Purpose: notify the client that the caller has been queued to fulfil calls.
      #
      # No parameters.
      ###
      LEGACY-way
      - unset call_id on campaign call model
      - clear & set contact (aka lead) info
      - clear script form
      - show placeholder contact message
      - hide contact info
      - update caller action buttons
      ###
      callerConnectedDialer: ->
        contactCache     = $cacheFactory.get('contact')
        console.log 'caller_connected_dialer (predictive only)'
        contactCache.remove('data')
      ##
      # caller_reassigned
      #
      # This event is published when a campaign admin assigns a caller to a
      # different campaign.
      # It is published for all campaign types (preview, power & predictive).
      #
      # Purpose: notify the client that the caller has been reassigned to a
      # different campaign.
      #
      # @param {object} {fields: Object, custom_fields: Object, {
      #                                                         phone,
      #                                                         custom_id,
      #                                                         last_name,
      #                                                         first_name,
      #                                                         middle_name,
      #                                                         suffix,
      #                                                         email,
      #                                                         address,
      #                                                         city,
      #                                                         state,
      #                                                         zip_code,
      #                                                         country
      #                                                        }}
      #
      # When received, the script should be fetched and the contact object passed
      # as the param should be rendered and a message displayed to the caller.
      ###
      LEGACY-way
      - fetch script for new campaign, if successful then continue
      - render new script
      - clear & set contact (aka lead) info
      - clear script form
      - hide placeholder contact message
      - show contact info
      - update caller action buttons
      - alert('You have been reassigned')
      ###
      callerReassigned: (contact) ->
        console.log 'caller_reassigned', contact

      ##
      # calling_voter
      #
      # This event is published when a contact (aka voter) is being dialed and
      # the dialer is in preview or power mode.
      #
      # Purpose: notify the client that the contact (aka voter) is being dialed.
      ###
      LEGACY-way
      - update caller action buttons
      ###
      callingVoter: ->
        console.log 'calling_voter'

      ##
      # voter_connected
      #
      # This event is published when a contact (aka voter) answers the phone in
      # preview or power mode.
      #
      # Purpose: notify the client that the contact (aka voter) has answered.
      #
      # @param {object} {call_id: Integer} The MySQL ID of the call record.
      ###
      LEGACY-way
      - set call_id on campaign call model
      - update caller action buttons
      ###
      voterConnected: (data) ->
        console.log 'voter_connected', data
        $state.go('dialer.active')
      ##
      # voter_connected_dialer
      #
      # This event is published when a contact (aka voter) answers the phone in
      # predictive mode.
      #
      # Purpose: notify the client that the contact (aka voter) has answered and
      # who the contact is (i.e. send contact data to the client).
      #
      # @param {object} {call_id: Integer, voter: Object} The Object assigned to
      # the voter key describes the contact.
      ###
      LEGACY-way
      - set call_id on campaign call model
      - clear & set contact (aka lead) info
      - clear script form
      - hide placeholder contact message
      - show contact info
      - update caller action buttons
      ###
      voterConnectedDialer: (data) ->
        contactCache     = $cacheFactory.get('contact')
        console.log 'voter_connected_dialer', data
        contactCache.put('data', data)
        $state.go('dialer.active')
      ##
      # voter_disconnected
      #
      # This event is published when a contact (aka voter) hangs up or is
      # otherwise disconnected from call in preview, power or predictive modes.
      #
      # Purpose: notify the client that the contact (aka voter) is no longer
      # connected.
      #
      # No parameters.
      ###
      LEGACY-way
      - update caller action buttons
      ###
      voterDisconnected: ->
        contactCache = $cacheFactory.get('contact')
        console.log 'voter_disconnected'
        contactCache.remove('data')
        $state.go('dialer.wrap')
      ##
      # caller_disconnected
      #
      # This event is published when the caller hangs up or is otherwise
      # disconnected from the call in preview, power or predictive modes.
      #
      # TODO: If caller was on a call they will have a chance to save any results.
      #
      # Purpose: notify the client that the caller is no longer connected.
      #
      # No parameters.
      callerDisconnected: ->
        console.log 'caller_disconnected'

      ##
      # transfer_busy
      #
      # This event is (currently) published from what seems to be an async Twilio
      # callback, indicating that it won't actually fire until the call has ended.
      #
      # TODO: Confirm above behavior and fix in back-end.
      ##
      # This event is published when a transfer has been dialed but the call was
      # not answered, busy or failed for some unknown reason.
      #
      # Purpose: notify the client that the attempted transfer has failed.
      #
      # No parameters.
      ###
      LEGACY-way
      - update caller action buttons
      ###
      transferBusy: ->
        console.log 'transfer_busy'

      ##
      # transfer_connected
      #
      # This event is published when the transfer party has answered the call
      # and Twilio requests the initial TwiML endpoint from the back-end,
      # immediately before the transfer is redirected to the conference.
      #
      # Purpose: notify the client that the transfer party has answered the call
      # and what kind of transfer it is (warm or cold).
      #
      # @param {object} {type: String} Where call_id is the
      # MySQL call record ID referencing the dialing of the transfer
      ###
      LEGACY-way
      - set transfer_type on campaign model to param.type
      - set transfer_call_id on campaign model to campaign model call_id
      ###
      transferConnected: (data) ->
        console.log 'transfer_connected', data

      ##
      # transfer_conference_ended
      #
      # This event is published when the transfer hangs up or is otherwise
      # disconnected and Twilio requests the call ending TwiML endpoint from
      # the back-end.
      #
      # Purpose: notify the client that the transfer is no longer connected.
      #
      # No parameters.
      ###
      LEGACY-way
      - iff transfer was disconnected by caller then trigger 'transfer.kicked' event
      - otherwise, iff transfer was warm then update caller action buttons
      - quietly unset 'kicking' property from campaign call model
      - unset 'transfer_type' property from campaign call model
      ###
      transferConferenceEnded: ->
        console.log 'transfer_conference_ended'

      ##
      # warm_transfer
      #
      # This event is published immediately after the caller is redirected to the
      # conference.
      #
      # Purpose: notify the client that the caller is now connected to the transfer.
      #
      # No parameters.
      ###
      LEGACY-way
      - update caller action buttons
      ###
      warmTransfer: ->
        console.log 'warm_transfer'

      ##
      # cold_transfer
      #
      # This event is published either immediately after the transfer is
      # redirected to the conference or immediately after the caller is
      # transitioned to the wrap-up phase of the call flow (which the caller
      # is iff there are any active transfers).
      #
      # Purpose: notify the client that the caller is transitioning or their
      # transition to the wrap-up phase is impending.
      #
      # No parameters.
      ###
      LEGACY-way
      - update caller action buttons
      ###
      coldTransfer: ->
        console.log 'cold_transfer'

      ##
      # caller_kicked_off
      #
      # This event is published when caller has hung up from 3-way call with
      # a warm transfer & contact.
      #
      # Purpose: notify the client that the caller is transitioning to the wrap-up
      # phase or the transition is impending.
      #
      # No parameters.
      ###
      LEGACY-way
      - update caller action buttons
      ###
      callerKickedOff: ->
        console.log 'caller_kicked_off'
    }
])

dialer.controller('DialerCtrl', [
  '$cacheFactory', 'Pusher', 'CallFlowFactory', 'callStation',
  ($cacheFactory,   Pusher,   CallFlowFactory,   callStation) ->
    callStationCache = $cacheFactory('callStation')
    callStationCache.put('data', callStation.data)
    channel = callStation.data.caller.session_key

    Pusher.subscribe(channel, 'start_calling', CallFlowFactory.startCalling)
    Pusher.subscribe(channel, 'conference_started', CallFlowFactory.conferenceStarted)
    Pusher.subscribe(channel, 'caller_connected_dialer', CallFlowFactory.callerConnectedDialer)
    Pusher.subscribe(channel, 'caller_reassigned', CallFlowFactory.callerReassigned)
    Pusher.subscribe(channel, 'calling_voter', CallFlowFactory.callingVoter)
    Pusher.subscribe(channel, 'voter_connected', CallFlowFactory.voterConnected)
    Pusher.subscribe(channel, 'voter_connected_dialer', CallFlowFactory.voterConnectedDialer)
    Pusher.subscribe(channel, 'voter_disconnected', CallFlowFactory.voterDisconnected)
    Pusher.subscribe(channel, 'caller_disconnected', CallFlowFactory.callerDisconnected)
    Pusher.subscribe(channel, 'transfer_busy', CallFlowFactory.transferBusy)
    Pusher.subscribe(channel, 'transfer_connected', CallFlowFactory.transferConnected)
    Pusher.subscribe(channel, 'transfer_conference_ended', CallFlowFactory.transferConferenceEnded)
    Pusher.subscribe(channel, 'warm_transfer', CallFlowFactory.warmTransfer)
    Pusher.subscribe(channel, 'cold_transfer', CallFlowFactory.coldTransfer)
    Pusher.subscribe(channel, 'caller_kicked_off', CallFlowFactory.callerKickedOff)
])

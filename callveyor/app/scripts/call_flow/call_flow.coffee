'use strict'

##
# The callFlowHandlers module is where the magic happens.
#
# This module:
# - provides canonical handlers for all remotely originating real-time (aka pusher) events
#   (ie for simplicity, these events should never be handled by another module in anyway, e.g. via $broadcast events or pusher directly)
# - should never make any $http requests directly
# - has sole-authority over the 'call' cache
# - manage a 'contact' cache
# - read from the 'callStation' cache
#
mod = angular.module('callveyor.call_flow', [
  'ui.router',
  'idFlash',
  'callveyor.http_dialer'
])

mod.factory('idCallFlow', [
    '$rootScope', '$state', '$cacheFactory', 'idHttpDialerFactory', 'idFlashFactory'
    ($rootScope,   $state,   $cacheFactory,   idHttpDialerFactory,   idFlashFactory) ->
      callCache     = $cacheFactory.get('call') || $cacheFactory('call')
      transferCache = $cacheFactory.get('transfer') || $cacheFactory('transfer')

      isWarmTransfer = -> /warm/i.test(transferCache.get('type'))

      handlers = {
        ##########################################
        # Handlers for events originating in-app #
        ##########################################
        ##
        # survey:save:success
        #
        # When this event is $broadcast from the survey module, transition to dialer.hold.
        survey: {
          save: {
            success: ->
              promise = $state.go('dialer.hold')
              error = (obj) ->
                # send err info to stats collector (e.g. errorception)
                # console.log 'error transitioning to dialer.hold on survey:save:success'
              promise.then(undefined,error)
          }
        }

        ############################################
        # Handlers for events originating remotely #
        ############################################
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
        startCalling: (data) ->
          callStationCache = $cacheFactory.get('callStation')
          callStation = callStationCache.get('data')
          # console.log 'start_calling', callStation
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

          # console.log 'conference_started (preview & power only)', contact, callStation

          if contact.campaign_out_of_leads
            idFlashFactory.now('warning', 'All contacts have been dialed! Please get in touch with your account admin for further instructions.', 20000)
            $state.go('dialer.stop')
            return

          contactCache.put('data', contact)
          $rootScope.$broadcast('contact:changed')

          $state.go('dialer.hold')

          if callStation.campaign.type == 'Power'
            caller = callStation.caller
            # console.log 'dialing for Power', caller
            idHttpDialerFactory.dial(caller.id, {
              session_id: caller.session_id,
              voter_id: contact.fields.id
            })
        ##
        # caller_connected_dialer
        #
        # This event is published immediately after `start_calling` is published.
        # It is also published each time a caller transitions from wrap-up to on-hold.
        # This event is sent instead of `conference_started` when in Predictive mode.
        #
        # Purpose: notify the client that the caller has been queued to fulfill calls.
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
          # console.log 'caller_connected_dialer (predictive only)'
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
          # console.log 'caller_reassigned', contact

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
          # console.log 'calling_voter'

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
          # console.log 'voter_connected', data
          callCache.put('id', data.call_id)
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
          # console.log 'voter_connected_dialer', data
          contactCache.put('data', data.voter)
          callCache.put('id', data.call_id)
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
          # console.log 'voter_disconnected'
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
          # console.log 'caller_disconnected', $state.is('dialer.active'), $state.current
          if $state.is('dialer.active')
            idFlashFactory.now('warning', 'The browser lost its voice connection. Please save any responses and Report problem if needed.')
            $state.go('dialer.wrap')
          else
            $state.go('dialer.ready')
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
          # console.log 'transfer_busy'

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
        # @param {object} {type: String, call_id: String} Where call_id is the
        # MySQL call record ID referencing the dialing of the transfer
        ###
        LEGACY-way
        - set transfer_type on campaign model to param.type
        - set transfer_call_id on campaign model to campaign model call_id
        ###
        transferConnected: (data) ->
          # console.log 'transfer_connected', data
          transferCache.put('id', data.call_id)
          transferCache.put('type', data.type)
          idFlashFactory.now('notice', 'Transfer connected.', 3000)

        ##
        # contact_joined_transfer_conference
        #
        # Purpose: notify client that the contact has been served the conf twiml.
        #
        contactJoinedTransferConference: ->
          console.log 'contactJoinedTransferConference'
          if not isWarmTransfer()
            # idFlashFactory.now('notice', 'Transfer & Contact connected.', 3000)
            $state.go('dialer.wrap')
          # else
          #   idFlashFactory.now('notice', 'Transfer & Contact connected.', 3000)

        ##
        # caller_joined_transfer_conference
        #
        # Purpose: notify client that the caller has been served the conf twiml.
        #
        callerJoinedTransferConference: ->
          console.log 'callerJoinedTransferConference'
          # idFlashFactory.now('notice', 'Transfer, Contact & you connected.', 3000)
          $state.go('dialer.active.transfer.conference')

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
          # console.log 'transfer_conference_ended'
          return if not isWarmTransfer()

          if $state.is('dialer.active.transfer.conference')
            idFlashFactory.now('notice', 'Transfer disconnected.', 3000)
            $state.go('dialer.active')
          else if $state.is('dialer.wrap')
            idFlashFactory.now('notice', 'All other parties have already disconnected.', 3000)

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
          console.log 'warm_transfer deprecated'
          # idFlashFactory.now('notice', 'Joining conference...', 3000)
          # $state.go('dialer.active.transfer.conference')

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
          console.log 'cold_transfer deprecated'
          # idFlashFactory.now('notice', 'Transfer complete.', 3000)
          # $state.go('dialer.wrap')

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
          # console.log 'caller_kicked_off'
          $state.go('dialer.wrap')
      }

      handlers
  ])
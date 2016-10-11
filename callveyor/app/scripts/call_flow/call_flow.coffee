'use strict'

##
# The callFlowHandlers module is where the magic happens.
#
# This module:
# - provides canonical handlers for all remotely originating real-time (aka pusher) events
#   (ie for simplicity, these events should never be handled by another module in anyway, e.g. via $broadcast events or pusher directly)
# - should never make any $http requests directly
# - has sole-authority over the 'call' cache
# - manage a 'household' cache
# - read from the 'callStation' cache
#
mod = angular.module('callveyor.call_flow', [
  'ui.router',
  'idFlash',
  'idTransition',
  'idCacheFactories',
  'Janitor',
  'callveyor.http_dialer'
])

mod.factory('CallerReassignedMessage', [
  ->
    callerReassignedMessage = (old_campaign, new_campaign) ->
      msg = ["An admin reassigned you to the \"#{new_campaign.name}\" campaign!"]

      return msg[0] if old_campaign.type == new_campaign.type

      isPreview    = (t) -> t.toLowerCase() == 'preview'
      isPower      = (t) -> t.toLowerCase() == 'power'
      isPredictive = (t) -> t.toLowerCase() == 'predictive'

      if isPreview(old_campaign.type)
        msg.push("Calls will now be dialed automatically.")

      if isPreview(new_campaign.type)
        msg.push("Calls will not be dialed until the 'Dial' button is clicked.")

      if isPredictive(new_campaign.type)
        msg.push("Contact info will not display until a call is answered.")

      msg.join(" ")

    callerReassignedMessage
])

mod.factory('idCallFlow', [
    '$rootScope', '$state', '$window', '$cacheFactory', 'CallCache', 'idJanitor', 'TransferCache', 'FlashCache', 'HouseholdCache', 'idHttpDialerFactory', 'idFlashFactory', 'usSpinnerService', 'idTransitionPrevented', 'CallStationCache', 'TwilioCache', 'CallerReassignedMessage',
    ($rootScope,   $state,   $window,   $cacheFactory,   CallCache,   idJanitor,   TransferCache,   FlashCache,   HouseholdCache,   idHttpDialerFactory,   idFlashFactory,   usSpinnerService,   idTransitionPrevented,   CallStationCache,   TwilioCache,   CallerReassignedMessage) ->
      isWarmTransfer = ->
        selected = TransferCache.get('selected')
        type     = TransferCache.get('type')
        # console.log('isWarmTransfer() -> selected transfer', selected)
        # console.log('isWarmTransfer() -> type', type)
        (selected? and /warm/i.test(selected.transfer_type)) or /warm/i.test(type)

      $window.idDebugData ||= {}

      beforeunloadBeenBound = false

      handlers = {
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
          caller = CallStationCache.get('caller')
          # console.log 'start_calling', caller
          caller.session_id = data.caller_session_id

          $window.idDebugData.caller = caller
          $window.Bugsnag.user = {id: caller.session_id}

        ##
        # conference_started
        #
        # This event is published immediately after `start_calling` is published.
        # It is also published each time a caller transitions from wrap-up to on-hold.
        #
        # Purpose: notify the client of new household data.
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

        conferenceStarted: (household) ->
          # console.log 'conference_started (preview & power only)', household

          campaign      = CallStationCache.get('campaign')
          campaign.type = household.dialer
          delete(household.dialer)

          if household.campaign_out_of_leads
            TwilioCache.put('disconnect_pending', true)
            FlashCache.put('error', 'All numbers have been dialed! Please get in touch with your account admin for further instructions.')
            HouseholdCache.put('data', {})
            $rootScope.$broadcast('household:changed')
            p = $state.go('abort')
            p.catch(idTransitionPrevented)
            return

          # console.log 'caching household', household

          HouseholdCache.put('data', household)
          $rootScope.$broadcast('household:changed')

          $window.idDebugData.campaign  = campaign
          $window.idDebugData.household = household

          p = $state.go('dialer.hold')
          p.catch(idTransitionPrevented)

          if campaign.type == 'Power'
            caller = CallStationCache.get('caller')
            # console.log 'dialing for Power', caller
            idHttpDialerFactory.dialContact(caller.id, {
              session_id: caller.session_id,
              phone: household.phone
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
        callerConnectedDialer: ->
          # console.log 'caller_connected_dialer (predictive only)'
          transitionSuccess = ->
            HouseholdCache.put('data', {})
            $rootScope.$broadcast('household:changed')

          p = $state.go('dialer.hold')
          p.then(transitionSuccess, idTransitionPrevented)
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
        # When received, the script should be fetched and the household object passed
        # as the param should be rendered and a message displayed to the caller.
        callerReassigned: (household) ->
          # console.log 'caller_reassigned', household
          deregister    = {}
          campaign      = CallStationCache.get('campaign')
          old_campaign  = angular.copy(campaign)
          campaign.name = household.campaign_name
          campaign.type = household.campaign_type
          campaign.id   = household.campaign_id
          delete(household.campaign_name)
          delete(household.campaign_type)
          delete(household.campaign_id)

          update = ->
            deregister()
            handlers.conferenceStarted(household)
            idFlashFactory.now('info', CallerReassignedMessage(old_campaign, campaign))

          deregister = $rootScope.$on('survey:load:success', update)
          $rootScope.$broadcast('survey:reload')
        ##
        # calling_voter
        #
        # This event is published when a household (aka voter) is being dialed and
        # the dialer is in preview or power mode.
        #
        # Purpose: notify the client that the household (aka voter) is being dialed.
        callingVoter: ->
          # console.log 'calling_voter'

        ##
        # voter_connected
        #
        # This event is published when a household (aka voter) answers the phone in
        # preview or power mode.
        #
        # Purpose: notify the client that the household (aka voter) has answered.
        #
        # @param {object} {call_sid: String} The Twilio SID of the call.
        voterConnected: (data) ->
          # console.log 'voter_connected', data
          CallCache.put('id', data.call_sid)
          $window.idDebugData.call_sid = data.call_sid
          p = $state.go('dialer.active')
          p.catch(idTransitionPrevented)
          # console.log CallCache.get('id'), CallCache.info()
        ##
        # voter_connected_dialer
        #
        # This event is published when a household (aka voter) answers the phone in
        # predictive mode.
        #
        # Purpose: notify the client that the household (aka voter) has answered and
        # who the household is (i.e. send household data to the client).
        #
        # @param {object} {call_sid: String, voter: Object} The Object assigned to
        # the voter key describes the household.
        voterConnectedDialer: (data) ->
          # console.log 'voter_connected_dialer', data
          transitionSuccess = ->
            HouseholdCache.put('data', data.household)
            $rootScope.$broadcast('household:changed')
            CallCache.put('id', data.call_sid)
            $window.idDebugData.household = data.household
            $window.idDebugData.call_sid   = data.call_sid

          p = $state.go('dialer.active')
          p.then(transitionSuccess, idTransitionPrevented)
        ##
        # voter_disconnected
        #
        # This event is published when a household (aka voter) hangs up or is
        # otherwise disconnected from call in preview, power or predictive modes.
        #
        # Purpose: notify the client that the household (aka voter) is no longer
        # connected.
        #
        # No parameters.
        voterDisconnected: ->
          # console.log 'voter_disconnected'
          unless isWarmTransfer()
            # console.log 'transitioning', TransferCache.get('type')
            p = $state.go('dialer.wrap')
            p.catch(idTransitionPrevented)
          else
            # console.log 'skipping transition'
        ##
        # caller_disconnected
        #
        # This event is published when the caller hangs up or is otherwise
        # disconnected from the call in preview, power or predictive modes.
        #
        # Purpose: notify the client that the caller is no longer connected.
        #
        # No parameters.
        callerDisconnected: ->
          # console.log 'caller_disconnected'
          if $state.is('dialer.active')
            # console.log '$state is dialer.active'
            idFlashFactory.now('danger', 'Your browser lost its voice connection. Please check your internet connection, submit your responses, and reload the page.')
            p = $state.go('dialer.wrap')
            p.catch(idTransitionPrevented)
          else if (not $state.is('dialer.wrap'))
            p = $state.go('dialer.ready')
            p.catch(idTransitionPrevented)

        ##
        # call_ended
        #
        callEnded: (data) ->
          # console.log 'call_ended', data
          status        = data.status
          campaign_type = data.campaign_type
          number        = data.number
          shouldReload  = ->
            status != 'completed' and $state.is('dialer.hold') and campaign_type != 'Predictive'
          if shouldReload()
            # console.log 'reloading dialer.hold $state'
            msg = "#{number} #{status}"
            idFlashFactory.nowAndDismiss('info', msg, 3000)
            holdCache = $cacheFactory.get('hold')
            hold = holdCache.get('sharedScope')
            hold.reset()

        ##
        # This event is published when a transfer has been dialed but the call was
        # not answered, busy or failed for some unknown reason.
        #
        # Purpose: notify the client that the attempted transfer has failed.
        #
        # No parameters.
        transferBusy: (data)  ->
          #console.log 'transfer_busy', data
          status = data.status
          label  = data.label
          msg    = "Transfer ended with #{data.status}"
          idFlashFactory.nowAndDismiss('info', msg, 3000)
          handlers.transferConferenceEnded()

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
        transferConnected: (data) ->
          # console.log 'transfer_connected', data
          # TransferCache.put('id', data.call_id)
          TransferCache.put('type', data.type)
          $window.idDebugData.transfer = {
            type: data.type,
            selected: TransferCache.get('selected')
          }
          # idFlashFactory.now('info', 'Transfer connected.')
          # $state.go('dialer.active.transfer.conference')

        ##
        # contact_joined_transfer_conference
        #
        # Purpose: notify client that the contact has been served the conf twiml.
        #
        contactJoinedTransferConference: ->
          # console.log 'contactJoinedTransferConference'
          if not isWarmTransfer()
            # idFlashFactory.now('info', 'Transfer & Contact connected.')
            p = $state.go('dialer.wrap')
            p.catch(idTransitionPrevented)
          # else
          #   idFlashFactory.now('info', 'Transfer & Contact connected.')

        ##
        # caller_joined_transfer_conference
        #
        # Purpose: notify client that the caller has been served the conf twiml.
        #
        callerJoinedTransferConference: ->
          # console.log 'callerJoinedTransferConference'
          # idFlashFactory.now('info', 'Transfer, Contact & you connected.')
          p = $state.go('dialer.active.transfer.conference')
          p.catch(idTransitionPrevented)

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
        transferConferenceEnded: ->
          isWarm = isWarmTransfer()

          selected = TransferCache.get('selected')
          if selected?
            TransferCache.put('hangup_method', 'kick')

          TransferCache.remove('type')
          TransferCache.remove('selected')

          return if not isWarm

          if $state.is('dialer.active.transfer.conference') or $state.is('dialer.active.transfer.selected') or $state.is('dialer.active.transfer.reselect')
            # idFlashFactory.now('info', 'Transfer disconnected.')
            p = $state.go('dialer.active')
            p.catch(idTransitionPrevented)
          # else if $state.is('dialer.wrap')
            # idFlashFactory.now('info', 'All other parties have already disconnected.')

        ##
        # warm_transfer
        #
        # This event is published immediately after the caller is redirected to the
        # conference.
        #
        # Purpose: notify the client that the caller is now connected to the transfer.
        #
        # No parameters.
        warmTransfer: ->
          console.log 'warm_transfer deprecated'
          # idFlashFactory.now('info', 'Joining conference...')
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
        coldTransfer: ->
          console.log 'cold_transfer deprecated'
          # idFlashFactory.now('info', 'Transfer complete.')
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
        callerKickedOff: ->
          # console.log 'caller_kicked_off'
          TransferCache.remove('type')
          TransferCache.remove('selected')
          p = $state.go('dialer.wrap')
          p.catch(idTransitionPrevented)

        callerWrapupVoiceHit: ->
          # in case end_call event is missed, tmp until pusher events are confirmed
          TransferCache.remove('type')
          TransferCache.remove('selected')
          if $state.is('dialer.hold')
            holdCache = $cacheFactory.get('hold')
            hold = holdCache.get('sharedScope')
            hold.reset()
          # /in case end_call event is missed, tmp until pusher events are confirmed

          p = $state.go('dialer.wrap')
          p.catch(idTransitionPrevented)

        messageDropError: (data) ->
          idFlashFactory.now('danger', data.message, 7000)

        messageDropSuccess: ->
          statePromise = $state.go('dialer.wrap')
          statePromise.catch($window.Bugsnag.notifyException)
      }

      handlers
  ])

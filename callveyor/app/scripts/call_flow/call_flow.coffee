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
  'idTransition',
  'idCacheFactories',
  'callveyor.http_dialer'
])

mod.factory('CallerReassignedMessage', [
  ->
    callerReassignedMessage = (old_campaign, new_campaign) ->
      msg = ["An admin reassigned you to a new campaign!"]

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
    '$rootScope', '$state', '$window', '$cacheFactory', 'CallCache', 'TransferCache', 'FlashCache', 'ContactCache', 'idHttpDialerFactory', 'idFlashFactory', 'usSpinnerService', 'idTransitionPrevented', 'CallStationCache', 'TwilioCache', 'CallerReassignedMessage',
    ($rootScope,   $state,   $window,   $cacheFactory,   CallCache,   TransferCache,   FlashCache,   ContactCache,   idHttpDialerFactory,   idFlashFactory,   usSpinnerService,   idTransitionPrevented,   CallStationCache,   TwilioCache,   CallerReassignedMessage) ->
      isWarmTransfer = -> /warm/i.test(TransferCache.get('type'))

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

          unless beforeunloadBeenBound
            beforeunloadBeenBound = true
            # Clean-up after closed windows
            stopFirst = (ev) ->
              caller_id         = caller.id
              params            = {}
              params.session_id = caller.session_id
              jQuery.ajax({
                url : "/call_center/api/#{caller_id}/stop_calling",
                data : params,
                type : "POST",
                async : false,
                success: ->
                  # Force the browser to wait for request to complete
                  # by setting async false and supplying a callback.
                  # Without the callback the page unload interrupts the request.
                  console.log 'Bye.'
              })

            $window.addEventListener('beforeunload', stopFirst)

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
          # console.log 'conference_started (preview & power only)', contact

          campaign      = CallStationCache.get('campaign')
          campaign.type = contact.dialer
          delete(contact.dialer)

          if contact.campaign_out_of_leads
            TwilioCache.put('disconnect_pending', true)
            FlashCache.put('error', 'All contacts have been dialed! Please get in touch with your account admin for further instructions.')
            ContactCache.put('data', {})
            $rootScope.$broadcast('contact:changed')
            p = $state.go('abort')
            p.catch(idTransitionPrevented)
            return

          ContactCache.put('data', contact)
          $rootScope.$broadcast('contact:changed')
          
          $window.idDebugData.campaign = campaign
          $window.idDebugData.contact  = contact

          p = $state.go('dialer.hold')
          p.catch(idTransitionPrevented)

          if campaign.type == 'Power'
            caller = CallStationCache.get('caller')
            # console.log 'dialing for Power', caller
            idHttpDialerFactory.dialContact(caller.id, {
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
          # console.log 'caller_connected_dialer (predictive only)'
          transitionSuccess = ->
            ContactCache.put('data', {})
            $rootScope.$broadcast('contact:changed')

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
          deregister    = {}
          campaign      = CallStationCache.get('campaign')
          old_campaign  = angular.copy(campaign)
          campaign.type = contact.campaign_type
          campaign.id   = contact.campaign_id
          delete(contact.campaign_type)
          delete(contact.campaign_id)

          update = ->
            deregister()
            handlers.conferenceStarted(contact)
            idFlashFactory.now('info', CallerReassignedMessage(old_campaign, campaign))

          deregister = $rootScope.$on('survey:load:success', update)
          $rootScope.$broadcast('survey:reload')
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
          # console.log 'voter_connected', data
          CallCache.put('id', data.call_id)
          $window.idDebugData.call_id = data.call_id
          p = $state.go('dialer.active')
          p.catch(idTransitionPrevented)
          # console.log CallCache.get('id'), CallCache.info()
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
          # console.log 'voter_connected_dialer', data
          transitionSuccess = ->
            ContactCache.put('data', data.voter)
            $rootScope.$broadcast('contact:changed')
            CallCache.put('id', data.call_id)
            $window.idDebugData.contact = data.voter
            $window.idDebugData.call_id = data.call_id

          p = $state.go('dialer.active')
          p.then(transitionSuccess, idTransitionPrevented)
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
          unless isWarmTransfer()
            # console.log 'transitioning', TransferCache.get('type')
            p = $state.go('dialer.wrap')
            p.catch(idTransitionPrevented)
          else
            console.log 'skipping transition'
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
          # console.log 'caller_disconnected'
          if $state.is('dialer.active')
            # console.log '$state is dialer.active'
            idFlashFactory.now('warning', 'Voice connection was lost. Save responses, report problem &amp; refresh page.')
            p = $state.go('dialer.wrap')
            p.catch(idTransitionPrevented)
          else
            # console.log '$state is NOT dialer.active'
            p = $state.go('dialer.ready')
            p.catch(idTransitionPrevented)

        ##
        # call_ended
        #
        callEnded: (data) ->
          console.log 'call_ended', data
          status        = data.status
          campaign_type = data.campaign_type
          number        = data.number
          shouldReload  = ->
            status != 'completed' and $state.is('dialer.hold') and campaign_type != 'Predictive'
          if shouldReload()
            console.log 'reloading dialer.hold $state'
            msg = "#{number} #{status}"
            idFlashFactory.nowAndDismiss('info', msg, 3000)
            # idFlashFactory.now('info', msg)
            holdCache = $cacheFactory.get('hold')
            hold = holdCache.get('sharedScope')
            hold.reset()

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
        # @param {object} {type: String, call_id: String} Where call_id is the
        # MySQL call record ID referencing the dialing of the transfer
        ###
        LEGACY-way
        - set transfer_type on campaign model to param.type
        - set transfer_call_id on campaign model to campaign model call_id
        ###
        transferConnected: (data) ->
          console.log 'transfer_connected', data
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
          console.log 'contactJoinedTransferConference'
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
          console.log 'callerJoinedTransferConference'
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
        ###
        LEGACY-way
        - iff transfer was disconnected by caller then trigger 'transfer.kicked' event
        - otherwise, iff transfer was warm then update caller action buttons
        - quietly unset 'kicking' property from campaign call model
        - unset 'transfer_type' property from campaign call model
        ###
        transferConferenceEnded: ->
          console.log 'transfer_conference_ended', $state.current

          isWarm = isWarmTransfer()

          TransferCache.remove('type')
          TransferCache.remove('selected')

          return if not isWarm

          if $state.is('dialer.active.transfer.conference')
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
        ###
        LEGACY-way
        - update caller action buttons
        ###
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
        ###
        LEGACY-way
        - update caller action buttons
        ###
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
        ###
        LEGACY-way
        - update caller action buttons
        ###
        callerKickedOff: ->
          # console.log 'caller_kicked_off'
          p = $state.go('dialer.wrap')
          p.catch(idTransitionPrevented)

        callerWrapupVoiceHit: ->
          # in case end_call event is missed, tmp until pusher events are confirmed
          if $state.is('dialer.hold')
            holdCache = $cacheFactory.get('hold')
            hold = holdCache.get('sharedScope')
            hold.reset()
          # /in case end_call event is missed, tmp until pusher events are confirmed

          console.log 'caller:wrapup:start'
          p = $state.go('dialer.wrap')
          p.catch(idTransitionPrevented)

        messageDropError: (data) ->
          console.log 'messageDropError', data
          idFlashFactory.now('danger', data.message, 7000)

        messageDropSuccess: ->
          console.log 'messageDropSuccess'

          statePromise = $state.go('dialer.wrap')
          statePromise.catch($window._errs.push)
      }

      handlers
  ])
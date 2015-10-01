module CallerEvents

  module ClassMethods
  end

  module InstanceMethods
  public
    def pushit(event_name, event_data={})
      RescueRetryNotify.on(Pusher::HTTPError, 1) do
        Pusher[session_key].trigger(event_name, event_data)
      end
    end

    def publish_start_calling
      pushit('start_calling', {caller_session_id: id, dialer: campaign.type})
    end

    def publish_voter_connected(call_sid, phone)

      if caller.is_phones_only? and campaign.predictive?
        account_sid = TWILIO_ACCOUNT
        dialed_call = CallFlow::Call::Dialed.new(account_sid, call_sid)
        lead        = campaign.dial_queue.households.auto_select_lead_for_disposition(phone)

        dialed_call.storage[:lead_uuid] = lead['uuid']

        return 
      end

      event_hash = campaign.voter_connected_event(call_sid, phone)

      pushit(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
    end

    def publish_voter_disconnected
      return if caller.is_phones_only?

      pushit("voter_disconnected", {})
    end

    def publish_caller_conference_started
      return if caller.is_phones_only?

      event_hash = campaign.caller_conference_started_event

      pushit(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
    end

    def publish_calling_voter
      return if caller.is_phones_only?

      pushit('calling_voter', {})
    end

    def publish_caller_disconnected
      return if caller.is_phones_only?

      pushit("caller_disconnected", {pusher_key: Pusher.key})
    end

    def publish_caller_reassigned
      return if caller.is_phones_only?

      event_hash = campaign.caller_conference_started_event

      pushit("caller_reassigned", event_hash[:data].merge!({
        dialer: campaign.type,
        campaign_name: campaign.name,
        campaign_id: campaign.id,
        campaign_type: campaign.type
      }))
    end

    def publish_call_ended(params)
      return if caller.is_phones_only?

      pushit('call_ended', {
        status: params['CallStatus'],
        campaign_type: params['campaign_type'],
        number: params['To']
      })
    end

    def publish_message_drop_error(message, data={})
      return if caller.is_phones_only?

      pushit('message_drop_error', data.merge({message: message}))
    end

    def publish_message_drop_success
      return if caller.is_phones_only?

      pushit('message_drop_success', {})
    end
  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
end

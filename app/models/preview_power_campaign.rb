module PreviewPowerCampaign
  def next_in_dial_queue
    house = nil

    timing('dialer.voter_load') do
      unless (phone_number = dial_queue.next(1).first).blank?
        house = {
          phone: phone_number,
          voters: dial_queue.households.find(phone_number)
        }
      end
    end

    return house
  end

  def caller_conference_started_event
    # tmp
    house = next_in_dial_queue
    if house.present?
      voter = house[:voters].first
      voter[:fields].merge!(phone: house[:phone])
      data  = voter
      inflight_stats.inc('presented')
    else
      data = {campaign_out_of_leads: true}
    end
    # /tmp

    return {
      event: 'conference_started',
      # tmp
      data:  data
      # /tmp
      # data: (next_in_dial_queue || {campaign_out_of_leads: true})
    }
  end

  def voter_connected_event(call)
    return {
      event: 'voter_connected',
      data: {call_id: call.id}
    }
  end
end

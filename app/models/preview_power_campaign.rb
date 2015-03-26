module PreviewPowerCampaign
  def number_ringing
    inflight_stats.incby('ringing', 1)
  end

  def number_failed
    # noop: provides consistent interface as Predictive
  end

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
    json = CallFlow::Web::Data.new(script)
    data = json.build(next_in_dial_queue)

    return {
      event: 'conference_started',
      data:  data
    }
  end

  def voter_connected_event(call)
    return {
      event: 'voter_connected',
      data: {call_id: call.id}
    }
  end
end

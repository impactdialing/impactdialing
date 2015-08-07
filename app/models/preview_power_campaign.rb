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
      house = dial_queue.next(1).try(:first)
    end

    return house
  end

  def caller_conference_started_event
    house = next_in_dial_queue
    
    json = CallFlow::Web::Data.new(script)
    data = json.build(house)

    return {
      event: 'conference_started',
      data:  data
    }
  end

  def voter_connected_event(call_sid, phone)
    return {
      event: 'voter_connected',
      data: {call_sid: call_sid}
    }
  end
end

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
    json = CallFlow::Web::Data.new(script)
    data = json.build(next_in_dial_queue)

    unless data[:campaign_out_of_leads]
      number_presented(1)
    else
      puts "#{self.type}[#{self.id}] - CampaignOutOfNumbers"
    end

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

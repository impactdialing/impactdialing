module PreviewPowerCampaign
  def timing(&block)
    namespace   = [self.type.downcase]
    namespace   << 'redis'
    namespace   << "ac-#{self.account_id}"
    namespace   << "ca-#{self.id}"
    bench_start = Time.now.to_f

    yield

    bench_end = Time.now.to_f

    ImpactPlatform::Metrics.measure('dialer.voter_load', (bench_end - bench_start), namespace.join('.'))
  end

  def next_in_dial_queue
    house = nil

    timing do
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

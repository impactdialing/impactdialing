module TimeHelpers
  def make_it_outside_calling_hours(campaign)
    campaign.update({
      start_time: Time.now.utc - 2.hour,
      end_time: Time.now.utc - 1.hour
    })
  end
end

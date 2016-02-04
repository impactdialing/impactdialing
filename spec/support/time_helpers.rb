module TimeHelpers
  def make_it_outside_calling_hours(campaign)
    Timecop.travel(Time.new(2015, 1, 1, 9).utc) do
      campaign.update_attributes({
        start_time: Time.now.utc - 2.hour,
        end_time: Time.now.utc - 1.hour
      })
    end
    return campaign
  end
end

module TimeZoneHelper
  
  def set_date_range(campaign, from_date, to_date)
    time_zone = ActiveSupport::TimeZone.new(campaign.time_zone || "UTC")
    begin
      from_date = Time.strptime("#{from_date} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if from_date
      to_date = Time.strptime("#{to_date} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if to_date
    rescue Exception => e
      flash_message(:error, I18n.t(:invalid_date_format))
      redirect_to :back
      return
    end      
    converted_from_date = (from_date || campaign.call_attempts.first.try(:created_at) || Time.now).in_time_zone(time_zone).beginning_of_day.utc      
    converted_to_date = (to_date || campaign.call_attempts.last.try(:created_at) || Time.now).in_time_zone(time_zone).end_of_day.utc
    [converted_from_date, converted_to_date]
  end
  
  def set_date_range_account(account, from_date, to_date)
    begin
      from_date = Time.strptime("#{from_date} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if from_date
      to_date = Time.strptime("#{to_date} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if to_date
    rescue Exception => e
      flash_message(:error, I18n.t(:invalid_date_format))
      redirect_to :back
      return
    end
    time_zone = ActiveSupport::TimeZone.new("UTC")
    converted_from_date = (from_date || account.try(:created_at)).in_time_zone(time_zone).beginning_of_day
    converted_to_date = (to_date || Time.now).in_time_zone(time_zone).end_of_day
    [converted_from_date, converted_to_date]
  end
  
  def time_for_date_picker(campaign, date)
    time_zone = ActiveSupport::TimeZone.new(campaign.try(:time_zone) || "UTC")
    date.in_time_zone(time_zone)    
  end
  
    
end
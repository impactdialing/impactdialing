module TimeZoneHelper
  
  def set_date_range(campaign, from_date, to_date)
    time_zone = campaign.as_time_zone || utc_time_zone
    converted_from_date = ( format_time(from_date, time_zone) || campaign.first_call_attempt_time ).in_time_zone(time_zone).beginning_of_day.utc      
    converted_to_date = ( format_time(to_date, time_zone) || campaign.last_call_attempt_time ).in_time_zone(time_zone).end_of_day.utc
    [converted_from_date, converted_to_date]
  end
  
  def set_date_range_callers(campaign, caller ,from_date, to_date)
    time_zone = campaign.as_time_zone || caller.as_time_zone || utc_time_zone
    if campaign.nil?
      converted_from_date = (formatted_from_date || CallerSession.find_by_caller_id(caller.id,:order=>"id asc", :limit=>"1").try(:created_at) || Time.now).in_time_zone(time_zone).beginning_of_day      
      converted_to_date = (formatted_to_date || CallerSession.find_by_caller_id(caller.id,:order=>"id desc", :limit=>"1").try(:created_at) || Time.now).in_time_zone(time_zone).end_of_day        
    else
      converted_from_date = (formatted_from_date || CallerSession.find_by_campaign_id(campaign.id,:order=>"id asc", :limit=>"1").try(:created_at) || Time.now).in_time_zone(time_zone).beginning_of_day      
      converted_to_date = (formatted_to_date || CallerSession.find_by_campaign_id(campaign.id,:order=>"id desc", :limit=>"1").try(:created_at) || Time.now).in_time_zone(time_zone).end_of_day        
    end
    [converted_from_date, converted_to_date]
  end
  
  def set_date_range_account(account, from_date, to_date)
    time_zone = utc_time_zone
    converted_from_date = (format_time(from_date) || account.try(:created_at) || Time.now).in_time_zone(time_zone).beginning_of_day
    converted_to_date = (format_time(to_date) || Time.now).in_time_zone(time_zone).end_of_day
    [converted_from_date, converted_to_date]
  end
  
  def format_time(date, time_zone)
    begin
      Time.strptime("#{date} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if date
    rescue Exception => e
      raise InvalidDateException
    end
  end
  
  def time_for_date_picker(campaign, date)
    time_zone = campaign.as_time_zone || utc_time_zone
    date.in_time_zone(time_zone)    
  end
  
  def time_for_date_picker_callers(campaign, caller, date)
   time_zone = campaign.as_time_zone || caller.as_time_zone || utc_time_zone
   date.in_time_zone(time_zone)    
  end  
  
  def utc_time_zone
    ActiveSupport::TimeZone.new("UTC")
  end
  
  
    
end
module TimeZoneHelper
  
  def set_date_range(campaign, from_date, to_date)
    time_zone = ActiveSupport::TimeZone.new(campaign.time_zone || "UTC")
    begin
      formatted_from_date = format_time(from_date, time_zone) 
      formatted_to_date = format_time(to_date, time_zone)
    rescue Exception => e
      flash_message(:error, I18n.t(:invalid_date_format))
      redirect_to :back
      return
    end      
    converted_from_date = (formatted_from_date || campaign.call_attempts.first.try(:created_at) || Time.now).in_time_zone(time_zone).beginning_of_day.utc      
    converted_to_date = (formatted_to_date || campaign.call_attempts.last.try(:created_at) || Time.now).in_time_zone(time_zone).end_of_day.utc
    [converted_from_date, converted_to_date]
  end
  
  def set_date_range_callers(campaign, caller ,from_date, to_date)
    time_zone = ActiveSupport::TimeZone.new(campaign.try(:time_zone) || caller.try(:campaign).try(:time_zone) || "UTC")
      begin
        formatted_from_date = format_time(from_date, time_zone)
        formatted_to_date = format_time(to_date, time_zone) 
      rescue Exception => e
        flash_message(:error, I18n.t(:invalid_date_format))
        redirect_to :back
        return
      end                    
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
    time_zone = ActiveSupport::TimeZone.new("UTC")
    begin
      formatted_from_date = format_time(from_date)
      formatted_to_date = format_time(to_date)
    rescue Exception => e
      puts "exception"
      flash_message(:error, I18n.t(:invalid_date_format))
      redirect_to :back
      return
    end    
    converted_from_date = (formatted_from_date || account.try(:created_at)).in_time_zone(time_zone).beginning_of_day
    converted_to_date = (formatted_to_date || Time.now).in_time_zone(time_zone).end_of_day
    [converted_from_date, converted_to_date]
  end
  
  def format_time(date, time_zone)
    Time.strptime("#{date} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if date
  end
  

  
  def time_for_date_picker(campaign, date)
    time_zone = ActiveSupport::TimeZone.new(campaign.try(:time_zone) || "UTC")
    date.in_time_zone(time_zone)    
  end
  
  def time_for_date_picker_callers(campaign, caller, date)
   time_zone = ActiveSupport::TimeZone.new(campaign.try(:time_zone) || caller.try(:campaign).try(:time_zone) || "UTC")
   puts time_zone
   date.in_time_zone(time_zone)    
  end
  
  
    
end
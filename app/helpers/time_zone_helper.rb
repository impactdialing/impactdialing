module TimeZoneHelper

  def set_date_range(campaign, from_date, to_date)
    time_zone = campaign.try(:as_time_zone) || pacific_time_zone
    converted_from_date = ( format_time(from_date, time_zone) || campaign.first_call_attempt_time || Time.now ).in_time_zone(time_zone).beginning_of_day.utc
    converted_to_date = ( format_time(to_date, time_zone) || campaign.last_call_attempt_time  || Time.now ).in_time_zone(time_zone).end_of_day.utc
    [converted_from_date, converted_to_date]
  end

  def set_date_range_with_time(campaign, from_date, to_date)
    time_zone = campaign.try(:as_time_zone) || pacific_time_zone
    converted_from_date = format_date_time(from_date, time_zone).in_time_zone(time_zone).utc
    converted_to_date = format_date_time(to_date, time_zone).in_time_zone(time_zone).utc
    [converted_from_date, converted_to_date]
  end


  def set_date_range_callers(campaign, caller ,from_date, to_date)
    time_zone = campaign.try(:as_time_zone) || caller.try(:as_time_zone) || pacific_time_zone
    converted_from_date = (format_time(from_date, time_zone) || first_caller_session_time(campaign, caller) || Time.now).in_time_zone(time_zone).beginning_of_day.utc
    converted_to_date = (format_time(to_date, time_zone) || last_caller_session_time(campaign, caller) || Time.now).in_time_zone(time_zone).in_time_zone(time_zone).end_of_day.utc
    [converted_from_date, converted_to_date]
  end

  def set_date_range_account(account, from_date, to_date)
    time_zone = pacific_time_zone
    converted_from_date = (format_time(from_date, time_zone) || account.try(:created_at) || Time.now).in_time_zone(time_zone).beginning_of_day.utc
    converted_to_date = (format_time(to_date, time_zone) || Time.now).in_time_zone(time_zone).end_of_day.utc
    [converted_from_date, converted_to_date]
  end

  def time_for_date_picker(campaign, date)
    time_zone = campaign.try(:as_time_zone) || pacific_time_zone
    date.in_time_zone(time_zone).strftime("%m/%d/%Y")
  end

  def time_for_date_picker_callers(campaign, caller, date)
   time_zone = campaign.try(:as_time_zone) || caller.try(:as_time_zone) || pacific_time_zone
   date.in_time_zone(time_zone).strftime("%m/%d/%Y")
  end

  private

    def first_caller_session_time(campaign, caller)
      campaign.nil? ? CallerSession.first_caller_time(caller).first.try(:created_at) : CallerSession.first_campaign_time(campaign).first.try(:created_at)
    end

    def last_caller_session_time(campaign, caller)
      campaign.nil? ? CallerSession.last_caller_time(caller).first.try(:created_at) : CallerSession.last_campaign_time(campaign).first.try(:created_at)
    end

    def format_time(date, time_zone)
      begin
        Time.strptime("#{date} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if date
      rescue Exception => e
        raise InvalidDateException
      end
    end

    def format_date_time(date, time_zone)
      begin
        Time.strptime("#{date} #{time_zone.formatted_offset}", "%m/%d/%Y %H:%M  %:z") if date
      rescue Exception => e
        raise InvalidDateException
      end
    end

    def pacific_time_zone
      ActiveSupport::TimeZone.new("Pacific Time (US & Canada)")
    end
end
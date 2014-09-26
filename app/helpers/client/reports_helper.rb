module Client::ReportsHelper
  # Takes date object and returns formatted string
  # like: 12:00am Jun 07, 2014
  def nice_date(date, time_zone='Pacific Time (US & Canada)')
    date.in_time_zone(time_zone).strftime('%l:%M%p %b %e, %Y')
  end

  # Takes date object and returns formatted string
  # like: 09/28/2011
  def date_as_slashes(date, time_zone='Pacific Time (US & Canada)')
    date.in_time_zone(time_zone).strftime('%m/%d/%Y')
  end
end
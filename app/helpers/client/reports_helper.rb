module Client::ReportsHelper
  # Takes date object and returns formatted string
  # like: 12:00am Jun 07, 2014
  def nice_date(date)
    date.strftime('%l:%M%p %b %e, %Y')
  end

  # Takes date object and returns formatted string
  # like: 09/28/2011
  def date_as_slashes(date)
    date.strftime('%m/%d/%Y')
  end
end
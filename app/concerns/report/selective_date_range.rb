# date range fix
# range = Report::SelectiveDateRange.new
# to = range.to.in_time_zone(c.time_zone).end_of_day
# from = to.beginning_of_day
class Report::SelectiveDateRange
  attr_reader :time_zone, :from_pool, :to_pool

private
  def normalize(datetime)
    if datetime.kind_of?(String)
      month, day, year = datetime.split('/')
      if month and day and year
        datetime = Time.new(year, month, day, 12, 0, 0, @time_zone.formatted_offset)
      end
    end
    datetime.in_time_zone(@time_zone)
  end

public
  def initialize(from_pool, to_pool=[], time_zone=nil)
    @from_pool = from_pool
    @to_pool   = to_pool
    @time_zone = ActiveSupport::TimeZone.new(time_zone || "Pacific Time (US & Canada)")
  end

  def from_before_normalize
    from_pool.compact.first
  end

  def to_before_normalize
    to_pool.compact.first || Time.now
  end

  def from
    normalize(from_before_normalize).beginning_of_day
  end

  def to
    normalize(to_before_normalize).end_of_day.utc
  end
end
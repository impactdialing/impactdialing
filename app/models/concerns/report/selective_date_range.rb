class Report::SelectiveDateRange
  class InvalidDateFormat < ArgumentError; end

  attr_reader :time_zone, :from_pool, :to_pool

private
  def verify_date_format!(datetime)
    return true if datetime =~ /\d+\/\d+\/\d+/

    invalid_date!
  end

  def invalid_date!
    raise InvalidDateFormat, "Date must be of format mm/dd/yyyy; eg 7/4/2014"
  end

  def normalize(datetime)
    if datetime.kind_of?(String)
      verify_date_format!(datetime)

      month, day, year = datetime.split('/')
      if month and day and year
        begin
          datetime = Time.new(year, month, day, 12, 0, 0, time_zone.now.formatted_offset)
        rescue ArgumentError => e
          invalid_date!
        end
      end
    else
      datetime = datetime.in_time_zone(time_zone)
    end
    datetime
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
    to_pool.compact.first || @time_zone.now
  end

  def from
    normalize(from_before_normalize).beginning_of_day.utc
  end

  def to
    normalize(to_before_normalize).end_of_day.utc
  end
end

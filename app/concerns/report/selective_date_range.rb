class Report::SelectiveDateRange
  attr_reader :timezone, :from_pool, :to_pool

private
  def normalize(datetime)
    if datetime.kind_of?(String)
      month, day, year = datetime.split('/')
      if month and day and year
        return Time.utc(year, month, day)
      end
    end
    datetime.utc
  end

public
  def initialize(from_pool, to_pool=[])
    @from_pool = from_pool
    @to_pool   = to_pool
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
    normalize(to_before_normalize).end_of_day
  end
end
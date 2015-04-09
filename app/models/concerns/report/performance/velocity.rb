class Report::Performance::Velocity
  attr_reader :record, :from_date, :to_date

private
  def rows
    [
      {heading: '<b>Dials /caller /hour</b>', number: :dial_rate},
      {heading: '<b>Answers /caller /hour</b>', number: :answer_rate},
      {heading: '<b>Average call length</b>', number: :average_call_length}
    ]
  end

  def headers
    headers = ['&nbsp;', 'Statistic']
  end

  def skip?(tpl)
    not skip_list.detect{|item| tpl.values.include?(item)}.nil?
  end

  def skip_list
    case @mode
    when :caller
      [:dial_rate]
    else
      []
    end
  end

  def caller_transformations
    [
      {column: '&nbsp;', rows_matcher: [1,:heading], value: '<b>Answers /hour</b>'}
    ]
  end

  def transformations
    case @mode
    when :caller
      caller_transformations
    else
      []
    end
  end

  def transform(row)
    transformation = transformations.each do |t|
      i       = t[:rows_matcher][0]
      key     = t[:rows_matcher][1]
      matcher = rows[i][key]

      if row[t[:column]] == matcher
        row[t[:column]] = t[:value]
      end
    end
    row
  end

public
  def initialize(options={})
    @record = options['record']
    @mode   = options['mode']
    @stats  = CallStats::Velocity.new(record, options)
  end

  def make
    table = Table(headers) do |feeder|
      rows.each do |tpl|
        next if skip?(tpl)

        feeder.transform{|row| self.send(:transform, row)}

        feeder << {
          '&nbsp;' => tpl[:heading],
          'Statistic' => @stats.send(tpl[:number])
        }
      end
    end
  end
end

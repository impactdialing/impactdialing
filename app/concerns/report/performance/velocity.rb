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

public
  def initialize(options={})
    @record = options['record']
    @stats  = CallStats::Velocity.new(record, options)
  end

  def make
    table = Table(headers) do |feeder|
      rows.each do |tpl|
        feeder << {
          '&nbsp;' => tpl[:heading],
          'Statistic' => @stats.send(tpl[:number])
        }
      end
    end
  end
end

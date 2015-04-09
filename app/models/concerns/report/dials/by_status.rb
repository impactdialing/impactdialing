class Report::Dials::ByStatus
  attr_reader :campaign

private
  def rows
    [
      {
        status: 'Answered',
        number: :answered_count
      },
      {
        status: '» Messages left by caller',
        number: :caller_left_message_count,
        percent: :caller_left_message_percent
      },
      {
        status: 'No answer',
        number: :not_answered_count
      },
      {
        status: 'Busy',
        number: :busy_count
      },
      {
        status: 'Answering machine',
        number: :machine_answered_count
      },
      {
        status: '» Messages left by machine',
        number: :machine_left_message_count,
        percent: :machine_left_message_percent
      },
      {
        status: 'Failed',
        number: :failed_count
      },
      {
        status: 'Abandoned',
        number: :abandoned_count
      },
      {
        status: 'Total',
        number: :total_count,
        hide_percent: true
      }
    ]
  end

  def headers
    headers = ['Status', 'Dials', 'Percent']
  end

  def total
    @stats.total_count
  end

  def dials_perc(dials)
    return '0%' if total.zero?
    
    dials ||= 0
    quo = dials / total.to_f
    "#{(quo * 100).round}%"
  end

public
  def initialize(options={})
    @campaign  = options[:campaign]
    @stats     = CallStats::ByStatus.new(campaign, options)
    @from_date = options[:from_date]
    @to_date   = options[:to_date]
  end

  def make
    table = Table(headers) do |feeder|
      rows.each do |tpl|
        dials                                 = @stats.send(tpl[:number])
        feeder.transform{|row| row['Dials']   = dials}
        feeder.transform do |row|
          if tpl[:percent]
            row['Percent'] = @stats.send(tpl[:percent])
          elsif tpl[:hide_percent]
            row['Percent'] = ''
          else
            row['Percent'] = dials_perc(dials)
          end
        end

        feeder << {'Status' => tpl[:status]}
      end
    end
  end
end

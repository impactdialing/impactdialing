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
        status: '» Compliance abandonment rate',
        percent: :fcc_abandon_rate,
        hide_dials: true
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

  def display_result_or_blank(method_name)
    if method_name.present?
      @stats.send(method_name)
    else
      ''
    end
  end

  def display_percent_or_blank(n)
    if n.present?
      dials_perc(n)
    else
      ''
    end
  end

  def display_result_or_percent_or_blank(method_name, n)
    [
      display_result_or_blank(method_name),
      display_percent_or_blank(n)
    ].reject(&:blank?).first
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
        dials   = display_result_or_blank(tpl[:number])
        percent = display_result_or_percent_or_blank(tpl[:percent], dials)

        feeder.transform do |row|
          row['Dials'] = dials
        end

        feeder.transform do |row|
          row['Percent'] = percent
        end
        feeder << {'Status' => tpl[:status]}
      end
    end
  end
end

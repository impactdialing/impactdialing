class Report::Dials::Summary
  attr_reader :campaign

private
  def rows
    [
      {
        status: 'Not dialed',
        number: :not_dialed_count
      },
      {
        status: 'Dialed and available for retry',
        number: :dialed_and_available_for_retry_count
      },
      {
        status: 'Dialed and not available for retry',
        number: :dialed_and_not_available_for_retry_count
      },
      {
        status: 'Dialed and complete',
        number: :dialed_and_complete_count
      },
      {
        status: 'Total # of contacts in all campaign lists',
        number: :all_voters_count
      }
    ]
  end

  def headers
    headers = ['Status', 'Number', 'Percent']
  end

  def total_voters
    @campaign.all_voters.count
  end

  def perc(n)
    n ||= 0
    quo = n / total_voters.to_f
    "#{(quo * 100).round}%"
  end

public
  def initialize(options={})
    @campaign = options['campaign']
    @stats = CallStats::Summary.new(campaign)
  end

  def make
    table = Table(headers) do |feeder|
      rows.each do |tpl|
        number = @stats.send(tpl[:number])
        feeder.transform{|row| row['Number'] = number}
        feeder.transform{|row| row['Percent'] = perc(number)}

        feeder << {'Status' => tpl[:status]}
      end
    end
  end
end

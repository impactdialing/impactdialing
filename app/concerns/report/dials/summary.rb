class Report::Dials::Summary
  attr_reader :campaign

private
  def rows
    [
      {
        status: 'Households not dialed',
        number: :households_not_dialed_count
      },
      {
        status: 'Voters not reached',
        number: :voters_not_reached,
        perc: 'N/A'
      },
      # {
      #   status: 'Dialed',
      #   number: :dialed_count
      # },
      # {
      #   status: 'Ringing',
      #   number: :ringing_count
      # },
      # {
      #   status: 'Failed',
      #   number: :failed_count
      # },
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
      }
      # ,
      # {
      #   status: 'Total # of contacts in all campaign lists',
      #   number: :all_voters_count
      # }
    ]
  end

  def headers
    headers = ['Status', 'Number', 'Percent']
  end

  def total_voters
    @total_voters ||= @campaign.all_voters.count(:id)
  end

  def perc(n)
    return '0%' if total_voters.zero?

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
        feeder.transform do |row|
          unless tpl[:perc]
            row['Percent'] = perc(number)
          else
            row['Percent'] = tpl[:perc]
          end
        end

        feeder << {'Status' => tpl[:status]}
      end
    end
  end
end

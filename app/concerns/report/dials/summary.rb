class Report::Dials::Summary
  attr_reader :campaign, :stats

private
  def rows
    [
      {
        status: 'Households not dialed',
        number: :households_not_dialed_count,
        perc: :household_perc
      },
      {
        status: 'People not reached',
        number: :voters_not_reached
      },
      {
        status: 'People dispositioned',
        number: :dialed_and_complete_count
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
        status: 'Households available for retry',
        number: :dialed_and_available_for_retry_count,
        perc: :household_perc
      },
      {
        status: 'Households not available for retry',
        number: :dialed_and_not_available_for_retry_count,
        perc: :household_perc
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
    @total_voters ||= campaign.all_voters.count(:id)
  end

  def total_households
    @total_households ||= campaign.households.count(:id)
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
    @stats    = CallStats::Summary.new(campaign)
  end

  def household_perc(n)
    return '0%' if total_households.zero?

    n ||= 0
    quo = n / total_households.to_f
    "#{(quo * 100).round}%"
  end

  def make
    table = Table(headers) do |feeder|
      rows.each do |tpl|
        number = stats.send(tpl[:number])
        feeder.transform{|row| row['Number'] = number}
        feeder.transform do |row|
          unless tpl[:perc]
            row['Percent'] = perc(number)
          else
            row['Percent'] = self.respond_to?(tpl[:perc]) ? self.send(tpl[:perc], number) : tpl[:perc]
          end
        end

        feeder << {'Status' => tpl[:status]}
      end
    end
  end
end

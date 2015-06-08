class Report::Dials::Summary
  include ActionView::Helpers::TextHelper

  attr_reader :campaign, :stats
# * Available to dial
#   * Not dialed: count of phone numbers not dialed
#   * Retrying: count of numbers dialed that have voters w/ call_back=true or status='not called'
# * Not available to dial
#   * Completed: count of phones where all voters have status!='not called' and call_back=false
#   * Pending retry: count of phones presented recently and have voters w/ call_back=true or status='not called'
#   * Phones blocked by Do Not Call list
#   * Cell phones scrubbed
# * Total
private
  def rows
    [
      {
        status: 'Available to dial',
        number: :total_households_to_dial,
        perc: :household_perc
      },
      {
        status: '» Not dialed',
        number: :households_not_dialed_count,
        perc: :household_perc
      },
      {
        status: '» Retrying',
        number: :dialed_and_available_for_retry_count,
        perc: :household_perc
      },
      {
        status: 'Not available to dial',
        number: :total_households_not_to_dial,
        perc: :household_perc
      },
      {
        status: '» Completed',
        number: :households_completely_dispositioned,
        perc: :household_perc
      },
      {
        status: '» Pending retry',
        number: :dialed_and_pending_retry,
        perc: :household_perc
      },
      {
        status: '» DNC matches',
        number: :households_blocked_by_dnc,
        perc: :household_perc
      },
      {
        status: '» Cell matches',
        number: :households_blocked_by_cell,
        perc: :household_perc
      },
      {
        status: 'Total',
        number: :total_households,
        perc: :household_perc
      }
    ]
  end

  def headers
    headers = ['Status', 'Number', 'Percent']
  end

  def total_households
    stats.total_households
  end

  def total_active_households
    stats.total_active_households
  end

public
  def initialize(options={})
    @campaign = options['campaign']
    @stats    = CallStats::Summary.new(campaign)
  end

  def pending_recycle_rate_message
    "» Dialed in last #{pluralize(campaign.recycle_rate, 'hour')}"
  end

  def household_perc(n)
    return '0%' if total_households.zero?

    n ||= 0
    quo = n / total_households.to_f
    "#{(quo * 100).floor}%"
  end

  def active_household_perc(n)
    return '0%' if total_active_households.zero?

    n ||= 0
    quo = n / total_active_households.to_f
    "#{(quo * 100).floor}%"
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

        feeder << {
          'Status' => self.respond_to?(tpl[:status]) ? self.send(tpl[:status]) : tpl[:status]
        }
      end
    end
  end
end

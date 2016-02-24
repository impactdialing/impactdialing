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
        perc:   :household_perc
      },
      {
        status: '» Not dialed',
        number: :not_dialed,
        perc:   :available_household_perc
      },
      {
        status: '» Retrying',
        number: :retrying,
        perc:   :available_household_perc
      },
      {
        status: 'Not available to dial',
        number: :total_households_not_to_dial,
        perc:   :household_perc
      },
      {
        status: '» Completed',
        number: :completed,
        perc:   :not_available_household_perc
      },
      {
        status: '» Pending retry',
        number: :pending_retry,
        perc:   :not_available_household_perc
      },
      {
        status: '» DNC matches',
        number: :households_blocked_by_dnc,
        perc:   :not_available_household_perc
      },
      {
        status: '» Cell matches',
        number: :households_blocked_by_cell,
        perc:   :not_available_household_perc
      },
      {
        status: 'Total',
        number: :total_households,
        perc:   :household_perc
      }
    ]
  end

  def headers
    ['Status', 'Households']
  end

  def perc(count=0, total)
    return '0%' if total.zero?

    quo = count / total.to_f
    "#{(quo * 100).floor}%"
  end

public
  def initialize(options={})
    @campaign = options['campaign']
    @stats    = CallStats::Summary.new(campaign)
  end

  def household_perc(n)
    perc(n, stats.total_households)
  end

  def available_household_perc(n)
    perc(n, stats.total_households_to_dial)
  end

  def not_available_household_perc(n)
    perc(n, stats.total_households_not_to_dial)
  end

  def make
    table = Table(headers) do |feeder|
      rows.each do |tpl|
        number = stats.send(tpl[:number])
        feeder.transform do |row|
          row['Households'] = "#{number} ("
          unless tpl[:perc]
            row['Households'] += perc(number)
          else
            row['Households'] += self.respond_to?(tpl[:perc]) ? self.send(tpl[:perc], number) : tpl[:perc]
          end
          row['Households'] += ')'
        end

        feeder << {
          'Status' => self.respond_to?(tpl[:status]) ? self.send(tpl[:status]) : tpl[:status]
        }
      end
    end
  end
end

class Report::Dials::Passes
  include ActionView::Helpers::TextHelper

  attr_reader :campaign, :stats
private
  def headers
    ['Pass', 'Households']
  end

  def perc(count=0, total)
    return '0%' if total.zero?

    quo = count / total.to_f
    "#{(quo * 100).floor}%"
  end

public
  def initialize(options={})
    @campaign = options['campaign']
    @stats    = CallStats::Passes.new(campaign)
  end

  def household_perc(n)
    "#{n} (#{perc(n, stats.total_households)})"
  end

  def make
    table = Table(headers) do |feeder|
      (stats.current_pass + 1).times do |pass|
        pass += 1
        number = stats.households_dialed_n_times(pass)
        feeder << {
          'Pass' => pass,
          'Households' => household_perc(number)
        }
      end
    end
  end
end

class Report::Dials::CampaignSummary
  attr_reader :campaign

  include Ruport::Controller::Hooks

private
  def campaign_methods
    [
      :dialed_and_not_available_for_retry_count, :dialed_and_available_for_retry_count,
      :not_dialed_count, :dialed_and_complete_count
    ]
  end

  def rows
    [
      {
        status: 'Not dialed',
        number: :not_dialed_count,
        percent: :not_dialed_percent
      },
      {
        status: 'Dialed and available for retry',
        number: :dialed_and_available_for_retry_count,
        percent: :dialed_and_available_for_retry_percent
      },
      {
        status: 'Dialed and not available for retry',
        number: :dialed_and_not_available_for_retry_count,
        percent: :dialed_and_not_available_for_retry_percent
      },
      {
        status: 'Dialed and complete',
        number: :dialed_and_complete_count,
        percent: :dialed_and_complete_percent
      }
    ]
  end

  def headers
    headers = ['Status', 'Number', 'Percent']
  end

public
  def initialize(options={})
    @campaign   = options['campaign']
    @from_date  = options['from_date']
    @to_date    = options['to_date']
  end

  def make
    table = Table(headers) do |t|
      rows.each do |tpl|
        row = {
          'Status' => tpl[:status],
          'Number' => campaign.send(tpl[:number]),
          'Percent' => campaign.send(tpl[:percent])
        }
        t << row
      end
    end
  end
end

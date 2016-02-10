require 'rails_helper'

feature 'Dials report', reports: true do
  include FakeCallData

  let(:admin){ create(:user) }
  let(:account){ admin.account }
  let(:campaign){ create_campaign_with_script(:bare_preview, account).last }

  before do
    add_callers(campaign, 1)
  end

  it 'loads the page without error' do
    web_login_as(admin)
    visit dials_client_reports_path(campaign_id: campaign.id)
    expect(page).to have_content "#{campaign.name} Dials"
  end
end

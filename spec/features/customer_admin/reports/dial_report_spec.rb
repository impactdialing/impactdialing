require 'rails_helper'

feature 'Dials report', reports: true do
  include FakeCallData

  before do
    @admin    = create(:user)
    @account  = @admin.account
    @campaign = create_campaign_with_script(:bare_preview, @account).last
    add_callers(@campaign, 1)
  end

  let(:admin){ @admin }
  let(:account){ @account }
  let(:campaign){ @campaign }
  let(:target_url){ dials_client_reports_path(campaign_id: campaign.id) }

  before do
    web_login_as(admin)
  end
  scenario 'Error-free page load when no dials have been made' do
    visit target_url
    expect(page).to have_content "#{campaign.name} Dials"
  end

  it_behaves_like 'any form with date picker'
end

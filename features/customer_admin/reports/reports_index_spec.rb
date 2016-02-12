require 'rails_helper'

feature 'Report index text', reports: true do
  include FakeCallData

  before(:all) do
    @admin    = create(:user)
    @account  = @admin.account
    @campaign = create_campaign_with_script(:bare_preview, @account).last
    add_callers(@campaign, 1)
  end

  let(:admin){ @admin }
  let(:account){ @account }
  let(:campaign){ @campaign }

  scenario 'When reports is visited it has text to let the client know how long the data will take to appear ' do
    web_login_as(admin)
    visit client_reports_path(campaign_id: campaign.id)
    expect(page).to have_content "Please allow 5 to 10 minutes for recent call data to appear"
  end
end

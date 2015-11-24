require 'rails_helper'

feature 'Dials report', sauce: ENV['USE_SAUCE'] do
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

  describe 'When no dials have been made' do
    before do
      web_login_as(admin)
    end
    it 'loads the page without error' do
      visit dials_client_reports_path(campaign_id: campaign.id)
      expect(page).to have_content "#{campaign.name} Dials"
    end
  end
end

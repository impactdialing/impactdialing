require 'rails_helper'

feature 'Dials report' do
  include FakeCallData

  create_campaign_with_script

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

  # describe 'When dummy data has been made' do
  #   before do
  #     web_login_as(admin)
  #   end
  #   it 'checks the page for correct data calculations' do
  #     visit dials_client_reports_path(campaign_id: campaign.id)
  #     save_and_open_page
  #     expect(page).to have_content "Abandoned 0 0%"
  #   end
  # end

end

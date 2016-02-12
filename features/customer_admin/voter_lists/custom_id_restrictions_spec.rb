require 'rails_helper'

feature 'Upload', js: true, sauce: ENV['USE_SAUCE'].present? do
  include_context 'voter csv import'
  let(:user){ create(:user) }
  let(:account){ user.account }
  let(:campaign) do
    create(:predictive, {
      account: account
    })
  end

  before do
    web_login_as(user)
  end

  context 'first voter list' do
    before do
      visit edit_client_campaign_path(campaign)
      upload_list('valid_voters_list_redis.csv')
    end

    it 'can map custom id' do
      expect(page).to have_css('option[value="custom_id"]')
      select 'ID', from: 'ID'
    end
  end

  context 'subsequent voter lists' do
    context 'when first voter list mapped custom id' do
      before do
        create(:voter_list, {
          campaign: campaign,
          csv_to_system_map: {
            'ID' => 'custom_id',
            'Phone' => 'phone'
          }
        })
      end

      it 'can map custom id' do
        visit edit_client_campaign_path(campaign)
        upload_list('valid_voters_list_redis.csv')
        expect(page).to have_css('option[value="custom_id"]')
        select 'ID', from: 'ID'
      end
    end

    context 'when first voter list did not map custom id' do
      before do
        create(:voter_list, {
          campaign: campaign,
          csv_to_system_map: {
            'Phone' => 'phone'
          }
        })
      end

      it 'cannot map custom id' do
        visit edit_client_campaign_path(campaign)
        upload_list('valid_voters_list_redis.csv')
        expect(page).to have_css('#csv_to_system_map_phone')
        expect(page).to_not have_css('option[value="custom_id"]')
      end
    end
  end
end

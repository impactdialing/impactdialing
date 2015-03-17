require 'spec_helper'

describe 'Display message to create callers and campaigns before viewing reports', type: :feature do
  include FakeCallData

  let(:admin){ create(:user) }
  let(:account){ admin.account }
  let(:base_error){ 'Please create at least one campaign and one caller before loading reports.' }

  scenario 'no callers exist' do
    create_campaign_with_script(:bare_preview, account)

    web_login_as(admin)
    visit client_reports_path

    expect(page).to have_content "#{base_error} Missing: callers"
  end

  scenario 'no campaigns or callers exist' do
    web_login_as(admin)
    visit client_reports_path

    expect(page).to have_content "#{base_error} Missing: campaigns and callers"
  end
end
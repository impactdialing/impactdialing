require 'rails_helper'

feature 'add caller group', admin: true do
  let(:customer) do
    create(:user)
  end
  before do
    web_login_as(customer)
  end
  it 'displays a link on the callers index page' do
    visit '/client/callers'
    click_on 'Manage caller groups'
    expect(page).to have_content 'Caller Groups'
    click_on 'Add new caller group' # double-check it is the right page
  end

  it 'allows callers to be assigned to a group when edited' do
    campaign = create(:power, {account: customer.account})
    group = create(:caller_group, {
      campaign: campaign,
      account: customer.account
    })
    caller = create(:caller, {
      account: customer.account,
      campaign: campaign
    })
    visit "/client/callers/#{caller.id}/edit"

    select "#{group.name}", from: 'Caller group'
  end

  it 'throws an error when an added caller group name is blank' do
    visit new_client_caller_group_path
    click_on 'Save'
    expect(page).to have_content "Name can't be blank"
  end
end

feature 'edit caller group', admin: true do
  let(:admin){ create(:user)}
  let(:account){ admin.account }
  let(:original_campaign){ create(:preview, account: account) }
  let!(:caller_group){ create(:caller_group, campaign: original_campaign, account: account) }
  let(:caller){ create(:caller, campaign: original_campaign, caller_group: caller_group, account: account) }
  let!(:new_campaign){ create(:predictive, account: account) }

  it 'gives proper notification when campaign is changed' do
    expect(account.campaigns).to include(original_campaign)
    web_login_as(admin)
    visit edit_client_caller_group_path(caller_group)
    select new_campaign.name, from: 'Campaign'
    click_on 'Save'
    expect(page).to have_content I18n.t('activerecord.successes.models.caller_group.reassigned')
  end

  it 'gives a different notification when name in caller group is changed or no changes are made' do
    expect(account.campaigns).to include(original_campaign)
    web_login_as(admin)
    visit edit_client_caller_group_path(caller_group)
    fill_in 'Name', with: 'different name'
    click_on 'Save'
    expect(page).to have_content "Caller Group saved"
  end

  it 'throws an error when an edited caller group name is blank' do
    expect(account.campaigns).to include(original_campaign)
    web_login_as(admin)
    visit edit_client_caller_group_path(caller_group)
    fill_in 'Name', with: ''
    click_on 'Save'
    expect(page).to have_content "Name can't be blank"
  end
end

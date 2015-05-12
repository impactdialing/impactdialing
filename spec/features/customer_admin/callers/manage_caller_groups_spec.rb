require 'rails_helper'

describe 'Caller Group Management', type: :feature, rack: true do
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
end

describe 'Edit Caller Group', type: :feature, rack: true do
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
save_and_open_page
    select new_campaign.name, from: 'Campaign'
    click_on 'Save'
    expect(page).to have_content "Caller has been reassigned to a different campaign.
    The change has been submitted and it might take a few minutes to update."
  end
end
# describe 'edit caller', :type => :feature do
#   include_context 'setup campaign'
#   let!(:caller){ create(:caller, campaign: campaign, account: account)}
#
#   it 'gives proper notification when campaign is changed' do
#     expect(account.campaigns).to include(campaign)
#     web_login_as(admin)
#     visit edit_client_caller_path(caller)
#     select '[None]', from: 'Campaign'
#     click_on 'Save'
#     expect(page).to have_content "Caller has been reassigned to a different campaign.
#     The change has been submitted and it might take a few minutes to update."
#   end
#
#   it 'gives noticed when saved.' do
#     expect(account.campaigns).to include(campaign)
#     web_login_as(admin)
#     visit edit_client_caller_path(caller)
#     fill_in 'Password', with: 'super_secret'
#     click_on 'Save'
#     expect(page).to have_content 'Changes saved.'
#   end
# end

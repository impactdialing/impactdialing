require 'spec_helper'

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

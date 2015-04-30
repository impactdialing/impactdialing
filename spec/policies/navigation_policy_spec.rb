require 'rails_helper'
require '../policies/navigation_policy'

describe NavigationPolicy do

  let(:admin) { create(:user) }
  let(:supervisor) { create(:user) }

  describe 'allow access to administrator' do
    web_login_as(admin)
    visit client_scripts_path
    expect(page).to have_content 'View archived scripts'
  end
  describe 'disallow access to supervisor' do
    web_login_as(supervisor)
    visit client_scripts_path
    expect(page).to have_content 'View archived scripts'
  end
end
#
# require 'rails_helper'
#
# feature 'include an "add a new campaign" link' do
#
#
#   describe 'adding a new caller' do
#     it 'adds a link to new_client_campaign_path if there are no callers' do
#       visit client_callers_path
#       click_on 'add a new campaign'
#       expect(page).to have_content 'New campaign'
#     end
#
#     it 'does not add a link to new_client_campaign_path if there is a caller' do
#       web_login_as(admin)
#       create(:caller, account: admin.account)
#       visit client_callers_path
#       expect(page).not_to have_content 'add a new campaign'
#     end
#   end
# end

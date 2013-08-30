require 'spec_helper'

feature 'add a subscription' do
  let(:user){ create(:user) }

  scenario 'select a Per minute subscription' do
    create_user_and_login
    visit client_subscription_path(1) # :id doesn't matter here; route should really be for singular resource
    select 'Basic', from: 'Select plan:'
    select 'Pro', from: 'Select plan:'
    select 'Business', from: 'Select plan:'
    select 'Per minute', from: 'Select plan:'
    # need js to test hide/show of form fields
    click_on 'Upgrade'

    #page.should have_content('Subscription Upgraded successfully')
  end
end
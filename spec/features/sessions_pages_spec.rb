require 'spec_helper'

feature 'a user signs in' do
  scenario 'with valid credentials' do
    user = Factory.create :user
    visit '/client/login'
    fill_in 'Email', :with => user.email
    fill_in 'Password', :with => user.new_password
    click_button 'Log in'
    page.should have_content 'Log out'
  end

  scenario 'with invalid credentials' do
    user = Factory.create :user
    visit '/client/login'
    fill_in 'Email', :with => 'wrong'
    fill_in 'Password', :with => 'wrong'
    click_button 'Log in'
    page.should have_content 'incorrect'
  end

  scenario 'logging out' do
    create_user_and_login
    click_link 'Log out'
    page.should have_content 'Log in'
  end
end

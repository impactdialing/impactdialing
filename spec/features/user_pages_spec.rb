require 'spec_helper'

feature 'when a user creates a new account' do
  xscenario 'with a valid email and password' do
    user = Factory.build :user
    visit '/client/login'
    fill_in 'Email address', :with => user.email
    fill_in 'Pick a password', :with => user.new_password
    click_button 'Sign up'
    page.should have_content 'Welcome! To get help for any page, click the Help button in the upper right corner.'
  end
end

feature 'when a user edits their information' do
  xscenario 'with valid information' do
    create_user_and_login
    click_link 'Account'
    fill_in 'Email address', :with => 'new@email.com'
    click_button 'Update info'
    page.should have_content 'Your information has been updated.'
  end

  xscenario 'and changes their password' do
    create_user_and_login
    user = Factory.build :user
    click_link 'Account'
    fill_in 'Current password', :with => user.new_password
    fill_in 'New password', :with => '1newpassword!'
    click_button 'Update password'
    page.should have_content 'Your password has been changed.'
  end

  xscenario 'and tries to change their password with an invalid password' do
    create_user_and_login
    click_link 'Account'
    fill_in 'Current password', :with => 'wrong'
    fill_in 'New password', :with => '1newpassword!'
    click_button 'Update password'
    page.should have_content 'Your current password was not correct.'
  end
end

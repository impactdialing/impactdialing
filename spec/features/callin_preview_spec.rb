require "spec_helper"


describe "CallinPreview" do
  include Capybara::DSL

  before(:each) do
    @account = Factory(:account)
    @campaign = Factory(:preview, account: @account)
    @caller = Factory(:caller, campaign: @campaign, account: @account,
    email: "test4@impactdialing.com", password: "demo123")
  end

  describe "Callin Preview Campaign" do
    it "should see the start calling button", js: true do
      visit "/caller/login"
      page.should have_content('Log in')
      fill_in "email", with: @caller.email
      fill_in "password", with: @caller.password
      click_link_or_button 'Log in'
      page.save_screenshot('tmp/poltergeist_screenshots/caller.png')
      page.should have_content('Start calling')
    end
  end
end

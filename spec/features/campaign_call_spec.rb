require "spec_helper"


describe "CampaignCall" do
  include Capybara::DSL
  before(:each) do
      @account = Factory(:account, subscription_name: "Manual", activated: true, card_verified: true)
      @script = Factory(:script)
      @script_text = Factory(:script_text, script_id: @script.id, content: "This is a script text", script_order: 1)

      @campaign = Factory(:preview, account: @account, script: @script)

      @caller = Caller.create(campaign: @campaign, account: @account, email: "nikhil@impact.com", password: "password")
      visit "/caller/login"
      page.should have_content('Log in')
      fill_in "email", with: @caller.email
      fill_in "password", with: @caller.password
      click_link_or_button 'Log in'
  end

  describe "Campaign Call Page"  do

    it "should display the script text" ,js: true do
      page.should have_content('This is a script text')
    end

    it "should display the start calling button" ,js: true do
      page.should have_content('Start calling')
    end

    it "should display lead information should appear here", js: true do
      page.should have_content('When connected, lead information will appear here.')
    end

    it "should display dialin number", js: true do
      page.should have_content('(415) 749-9271')
    end

    it "should display PIN", js: true do
      find('#callin-pin').should have_content(@caller.caller_identities.last.pin)
    end

  end
end
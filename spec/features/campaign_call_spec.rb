require "integration_spec_helper"


describe "CampaignCall" do
  include Capybara::DSL


  before(:each) do
      @account = Factory(:account, subscription_name: "Manual", activated: true, card_verified: true)
      @script = Factory(:script)
      @script_text = Factory(:script_text, script_id: @script.id, content: "This is a script text", script_order: 1)
      @question = Factory(:question, script_id: @script.id, text: "Whats the question?", script_order: 2)
      @possible_response = Factory(:possible_response, question_id: @question.id, keypad: 1, value: "Test", retry:false,
        possible_response_order: 1)
      @note = Factory(:note, script_id: @script.id, note: "Whats your note?", script_order: 3)
      @campaign = Factory(:preview, account: @account, script: @script)
      @caller = Factory(:caller, account: @account, campaign: @campaign, email: "nikhil@impact.com", password: "password")

      visit "/caller/login"
      page.should have_content('Log in')
      puts Caller.count
      fill_in "email", with: @caller.email
      fill_in "password", with: @caller.password
      click_link_or_button 'Log in'
  end

  describe "Campaign Call Page"  do

    it "should display the page correcty" ,js: true do
      page.should have_content('This is a script text')
      page.should have_content('Whats the question?')
      page.should have_content("Test")
      page.should have_content('Whats your note?')
      page.should have_content('Start calling')
      page.should have_content('When connected, lead information will appear here.')
      page.should have_content('(415) 749-9271')
      find('#callin-pin').should have_content(@caller.caller_identities.last.pin)
    end

  end
end
require "spec_helper"


describe "PreviewCampaignCall" do
  include Capybara::DSL
  Capybara.app_host = 'http://impact.localtunnel.net'
  Capybara.server_port = '8989'

  before(:all) do
      puts ENV["RAILS_ENV"]
      @account = Factory(:account, subscription_name: "Manual", activated: true, card_verified: true)
      @script = Factory(:script)
      @script_text = Factory(:script_text, script_id: @script.id, content: "This is a script text", script_order: 1)
      @question = Factory(:question, script_id: @script.id, text: "Whats the question?", script_order: 2)
      @possible_response = Factory(:possible_response, question_id: @question.id, keypad: 1, value: "Test", retry:false,
        possible_response_order: 1)
      @note = Factory(:note, script_id: @script.id, note: "Whats your note?", script_order: 3)

      @campaign = Factory(:preview, account: @account, script: @script)

      @caller = Factory(:caller, account: @account, campaign: @campaign, email: "nikhil@impact.com", password: "password")
      puts ActiveRecord::Base.connection.current_database
      visit "/caller/login"
      page.should have_content('Log in')
      fill_in "email", with: @caller.email
      fill_in "password", with: @caller.password
      click_link_or_button 'Log in'
  end

  it "should click on start calling and see dial button" do
    click_link 'Start calling'
    sleep 30.seconds
    find_link('Dial').visible?


  end
end
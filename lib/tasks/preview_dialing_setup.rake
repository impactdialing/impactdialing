desc "Update twilio call data"

namespace :seed do
  task :pd => :environment do
    empty
    campaign = Campaign.create(:name => "Test", :campaign_id => "12345", :user => user, :script => script, :type => Campaign::Type::PREVIEW, :use_web_ui => true, :caller_id_verified => true)
    campaign.callers.create(:name => "aninda", :email => user.email, :user => user, :pin => "12345", :password => "password")
    campaign.all_voters.create(:Phone => "+14154486970",:campaign => campaign)
  end

  def script
    @script ||= Script.create(:user => user, :name => "test", :active => true, :script => "This is a test script.")
    @script
  end

  def user
    @user||= User.create(:fname => "Aninda", :email => "aninda@mailinator.com", :activated => true, :new_password => 'password', :phone => "9165959543")
    @user
  end

  def empty
    Campaign.destroy_all
    Caller.destroy_all
    User.destroy_all
    Voter.destroy_all
  end
end



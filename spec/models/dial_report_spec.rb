require "spec_helper"    

describe DialReport do
  include ApplicationHelper::TimeUtils
  
  describe "overview" do
    
    describe "dial and completed" do
    
      it "should include all successful call attempts" do
        @campaign = Factory(:predictive)
        voter1 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter2 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter3 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
      
        call_attempt1 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter1)
        voter1.update_attributes(last_call_attempt_time: call_attempt1.created_at)
        call_attempt2 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter2)
        voter2.update_attributes(last_call_attempt_time: call_attempt2.created_at)
        call_attempt3 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3)
        voter3.update_attributes(last_call_attempt_time: call_attempt3.created_at)      
        call_attempt4 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4)
        voter4.update_attributes(last_call_attempt_time: call_attempt4.created_at)            
      
        from_date = CallAttempt.find_all_by_campaign_id(@campaign.id).first.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).beginning_of_day
        to_date = CallAttempt.find_all_by_campaign_id(@campaign.id).last.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).end_of_day
        dial_report = DialReport.new
        dial_report.compute_campaign_report(@campaign, from_date, to_date)
        dial_report.dialed_and_completed.should eq(2)      
      end
    
      it "should include all failed call attempts" do
        @campaign = Factory(:predictive)
        voter1 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now)
        voter2 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now)
        voter3 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
      
        call_attempt1 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now, voter: voter1)
        voter1.update_attributes(last_call_attempt_time: call_attempt1.created_at)
        call_attempt2 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now, voter: voter2)
        voter2.update_attributes(last_call_attempt_time: call_attempt2.created_at)
        call_attempt3 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3)
        voter3.update_attributes(last_call_attempt_time: call_attempt3.created_at)      
        call_attempt4 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4)
        voter4.update_attributes(last_call_attempt_time: call_attempt4.created_at)            
      
        from_date = CallAttempt.find_all_by_campaign_id(@campaign.id).first.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).beginning_of_day
        to_date = CallAttempt.find_all_by_campaign_id(@campaign.id).last.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).end_of_day
        dial_report = DialReport.new
        dial_report.compute_campaign_report(@campaign, from_date, to_date)
        dial_report.dialed_and_completed.should eq(2)      
      end
    
      it "should include all successful failed call attempts" do
        @campaign = Factory(:predictive)
        voter1 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter2 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now)
        voter3 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
      
        call_attempt1 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter1)
        voter1.update_attributes(last_call_attempt_time: call_attempt1.created_at)
        call_attempt2 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now, voter: voter2)
        voter2.update_attributes(last_call_attempt_time: call_attempt2.created_at)
        call_attempt3 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3)
        voter3.update_attributes(last_call_attempt_time: call_attempt3.created_at)      
        call_attempt4 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4)
        voter4.update_attributes(last_call_attempt_time: call_attempt4.created_at)            
      
        from_date = CallAttempt.find_all_by_campaign_id(@campaign.id).first.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).beginning_of_day
        to_date = CallAttempt.find_all_by_campaign_id(@campaign.id).last.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).end_of_day
        dial_report = DialReport.new
        dial_report.compute_campaign_report(@campaign, from_date, to_date)
        dial_report.dialed_and_completed.should eq(2)      
      end
    end
    
    describe "available and retry" do
      it "should include all successful call attempts" do
        @campaign = Factory(:predictive)
        voter1 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter2 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter3 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4 = Factory(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)

        call_attempt1 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter1)
        voter1.update_attributes(last_call_attempt_time: call_attempt1.created_at)
        call_attempt2 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter2)
        voter2.update_attributes(last_call_attempt_time: call_attempt2.created_at)
        call_attempt3 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3)
        voter3.update_attributes(last_call_attempt_time: call_attempt3.created_at)      
        call_attempt4 = Factory(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4)
        voter4.update_attributes(last_call_attempt_time: call_attempt4.created_at)            

        from_date = CallAttempt.find_all_by_campaign_id(@campaign.id).first.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).beginning_of_day
        to_date = CallAttempt.find_all_by_campaign_id(@campaign.id).last.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).end_of_day
        dial_report = DialReport.new
        dial_report.compute_campaign_report(@campaign, from_date, to_date)
        dial_report.dialed_and_completed.should eq(2)      
      end      
    end
    
    
    
  end
end

require "spec_helper"

describe 'new simulator' do
  
  # it "should give default values" do
  #   campaign = Factory(:campaign)
  #   start_time = 60 * 10
  #   25.times{Factory(:caller_session, available_for_call: true, on_call: true, campaign_id: campaign.id)}
  #   call_status = [CallAttempt::Status::SUCCESS,CallAttempt::Status::INPROGRESS,CallAttempt::Status::NOANSWER,
  #     CallAttempt::Status::ABANDONED,CallAttempt::Status::SUCCESS,CallAttempt::Status::BUSY,CallAttempt::Status::FAILED]
  #   
  #   100.times do |index|
  #     created_at = Time.now + index - Random.rand(9).minutes
  #     status = call_status.sample
  #     if status = CallAttempt::Status::SUCCESS
  #       duration = [30,20,40,90,22,35].sample
  #     else
  #       duration = [1,2,3,4,5].sample
  #     end
  #     
  #     connect_duration = [1,2,3,4,5].sample
  #     Factory(:call_attempt, created_at: created_at, campaign_id: campaign.id, status: call_status.sample, connecttime: created_at + connect_duration,
  #     call_start: created_at + 2.seconds, wrapup_time: created_at + duration )      
  #   end
  #   
  #   actual = simulator_campaign_base_values(campaign.id, start_time)
  #   puts "Expected Conversation: #{actual.first}"
  #   puts "Longest Conversation: #{actual[1]}"    
  #   puts "Available Callers: #{actual[2].length}"
  #   puts "Observed Conversations: #{actual[3].length}"
  #   puts "Observed Dials: #{actual[4].length}"
  # end
  # 
  # it "should simulate with 10 minutes prior data " do
  #       campaign = Factory(:campaign, acceptable_abandon_rate: 0.3 )
  #       start_time = 60 * 10
  #       25.times{Factory(:caller_session, available_for_call: true, on_call: true, campaign_id: campaign.id)}
  #       call_status = [CallAttempt::Status::SUCCESS,CallAttempt::Status::INPROGRESS,CallAttempt::Status::NOANSWER,
  #         CallAttempt::Status::ABANDONED,CallAttempt::Status::SUCCESS,CallAttempt::Status::BUSY,CallAttempt::Status::FAILED]
  #       
  #       100.times do |index|
  #         created_at = Time.now + index - Random.rand(9).minutes
  #         status = call_status.sample
  #         if status == CallAttempt::Status::SUCCESS
  #           duration = [30,20,40,90,22,35].sample
  #         else
  #           duration = [1,2,3,4,5].sample
  #         end
  #         
  #         connect_duration = [1,2,3,4,5].sample
  #         Factory(:call_attempt, created_at: created_at, campaign_id: campaign.id, status: call_status.sample, connecttime: created_at + connect_duration,
  #         call_start: created_at + 2.seconds, wrapup_time: created_at + duration )      
  #       end
  #       
  #       actual = simulate(campaign.id)
  #     end
  # 
  # it "should simulate without 10 minutes prior data " do
  #   campaign = Factory(:campaign, acceptable_abandon_rate: 0.3 )
  #   actual = simulate(campaign.id)
  # end
  # 
end
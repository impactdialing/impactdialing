require 'spec_helper'

describe EndCallerSessionJob do

  let!(:campaign) { create(:campaign) }
  let!(:caller) { create(:caller, campaign_id: campaign.id) }
  let!(:caller_session) { create(:caller_session, caller_id: caller.id, campaign_id: campaign.id) }
  let!(:voters) do
    voters = []
    voters += (1..50).map do
     create(:voter,
       campaign_id: campaign.id,
       status: CallAttempt::Status::SUCCESS,
       caller_id: caller.id
     )
    end
    voters += (1..110).map do
     create(:voter,
       campaign_id: campaign.id,
       status: CallAttempt::Status::READY,
       caller_id: caller.id
     )
    end
    voters
  end

  before(:each) do
    EndCallerSessionJob.new.perform(caller_session.id)
  end

  it "should set 'not called' status for all voters" do
    voters.each(&:reload)
    voters.select { |v| v.status == 'not called' }.should have(110).items
    voters.select { |v| v.status == CallAttempt::Status::SUCCESS }.should have(50).items
  end

end

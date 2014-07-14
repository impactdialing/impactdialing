require "spec_helper"
require Rails.root.join("lib/cleanup_in_progress_call_attempts.rb")

describe CleanupInProgressCallAttempts do
  
  let!(:campaign) { create(:campaign) }
  
  def create_pair(status, data ={})
    ca = create(:call_attempt, data.merge({:status => status, :campaign => campaign, created_at: 2.days.ago}))
    voter = create(:voter, :status => status, :last_call_attempt => ca, :campaign => campaign, created_at: 2.days.ago)
    ca.voter = voter
    ca.save
  end
  

  context "for all" do
    before(:each) do
    
      @statuses = ['Ringing', 'Call in progress', 'Call ready to dial']
      create_pair('Call completed with success.', {:call_start => Time.now, :call_end => Time.now, :connecttime => Time.now})
      @statuses.each do |status|  
        ca = create(:call_attempt, {:status => status, :call_start => nil, :call_end => nil, :connecttime => nil})
        create_pair(status, {:call_start => nil, :call_end => nil, :connecttime => nil})
        create_pair(status, {:call_start => nil, :call_end => nil, :connecttime => Time.now})
        create_pair(status, {:call_start => nil, :call_end => Time.now, :connecttime => nil})
        create_pair(status, {:call_start => nil, :call_end => Time.now, :connecttime => Time.now})
        create_pair(status, {:call_start => Time.now, :call_end => nil, :connecttime => nil})
        create_pair(status, {:call_start => Time.now, :call_end => nil, :connecttime => Time.now})
        create_pair(status, {:call_start => Time.now, :call_end => Time.now, :connecttime => nil})
        create_pair(status, {:call_start => Time.now, :call_end => Time.now, :connecttime => Time.now})
      end
      CleanupInProgressCallAttempts.cleanup!
    end

    it "should create 'not called'" do
      expect(Voter.where(:status => 'not called').count).to eq(4 * @statuses.size)
      expect(CallAttempt.where(:status => 'not called').count).to eq(5 * @statuses.size)
    end

    it "should create 'No answer'" do
      expect(Voter.where(:status => 'No answer').count).to eq(1 * @statuses.size)
      expect(CallAttempt.where(:status => 'No answer').count).to eq(1 * @statuses.size)
    end

    it "should create 'Call abandoned'" do
      expect(Voter.where(:status => 'Call abandoned').count).to eq(1 * @statuses.size)
      expect(CallAttempt.where(:status => 'Call abandoned').count).to eq(1 * @statuses.size)
    end

    it "should create 'Call failed'" do
      expect(Voter.where(:status => 'Call failed').count).to eq(2 * @statuses.size)
      expect(CallAttempt.where(:status => 'Call failed').count).to eq(2 * @statuses.size)
    end
  end
  
  context "for campaign" do
    before(:each) do
      ca = create(:call_attempt, :status => 'not called')
      voter = create(:voter, :status => 'not called', :last_call_attempt => ca, created_at: 2.days.ago)
      ca.voter = voter
      ca.save
      @statuses = ['not called']
      create_pair('Call completed with success.', {:call_start => Time.now, :call_end => Time.now, :connecttime => Time.now})
      @statuses.each do |status|  
        ca = create(:call_attempt, {:campaign => campaign, :status => status, :call_start => Time.now, :call_end => nil, :connecttime => nil, created_at: 2.days.ago})
        create_pair(status, {:call_start => Time.now, :call_end => nil, :connecttime => nil})
        create_pair(status, {:call_start => Time.now, :call_end => nil, :connecttime => Time.now})
        create_pair(status, {:call_start => Time.now, :call_end => Time.now, :connecttime => nil})
        create_pair(status, {:call_start => Time.now, :call_end => Time.now, :connecttime => Time.now})
      end
      CleanupInProgressCallAttempts.cleanup_for_campaigns!([campaign.id])
    end
    
    it "should create 'No answer'" do
      expect(Voter.where(:status => 'No answer').count).to eq(1 * @statuses.size)
      expect(CallAttempt.where(:status => 'No answer').count).to eq(2 * @statuses.size)
    end

    it "should create 'Call abandoned'" do
      expect(Voter.where(:status => 'Call abandoned').count).to eq(1 * @statuses.size)
      expect(CallAttempt.where(:status => 'Call abandoned').count).to eq(1 * @statuses.size)
    end

    it "should create 'Call failed'" do
      expect(Voter.where(:status => 'Call failed').count).to eq(2 * @statuses.size)
      expect(CallAttempt.where(:status => 'Call failed').count).to eq(2 * @statuses.size)
    end
    
  end
  
end

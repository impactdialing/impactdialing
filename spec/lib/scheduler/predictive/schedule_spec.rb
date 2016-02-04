require 'celluloid_helper'
require 'scheduler'

class Woo < Scheduler::Predictive::Schedule
  attr_accessor :processed_campaigns

  def initialize(*args)
    super
    @processed_campaigns = []
  end

  def process(campaign)
    p "processing #{campaign.id}"
    @processed_campaigns << campaign
  end

  def current_instance
    Actor.current
  end
end

describe Scheduler::Predictive::Schedule do
  include_context 'setup celluloid'

  def setup(target)
    campaigns = create_list(:predictive, 5)
    allow(RedisPredictiveCampaign).to receive(:running_campaigns){
      campaigns.map(&:id)
    }
    return campaigns
  end

  describe '#campaigns_to_dial' do
    it 'returns AR Relation of Predictive campaigns identified by RedisPredictiveCampaign.running_campaigns' do
      target = Woo.new(1)
      campaigns = setup(target)
      expect(target.campaigns_to_dial.to_a).to eq campaigns
    end
  end

  describe '#run' do
    it 'tells itself to #process each campaign from #campaigns_to_dial' do
      target = Woo.new(0.2)
      campaigns = setup(target)
      target.run
      sleep 0.21
      target.processed_campaigns
      expect(target.processed_campaigns.uniq).to eq campaigns
    end
  end
end

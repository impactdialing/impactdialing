require 'celluloid_helper'
require 'scheduler'

describe Scheduler::Predictive::Simulator do
  include_context 'setup celluloid'

  subject{ Scheduler::Predictive::Simulator.new(60) }
  let(:campaign){ create(:predictive) }
  describe '#process(campaign)' do
    it 'queues SimulatorJob for campaign' do
      subject.process(campaign)
      expect([:resque, :simulator_worker]).to have_queued(SimulatorJob).with(campaign.id)
    end
  end
end

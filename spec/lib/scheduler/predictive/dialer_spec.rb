require 'celluloid_helper'
require 'scheduler'

describe Scheduler::Predictive::Dialer do
  include_context 'setup celluloid'
  subject{ Scheduler::Predictive::Dialer.new(60) }
  describe '#process(campaign)' do
    let(:campaign){ create(:predictive) }
    it 'tells CalculateDialsJob to add_to_queue(campaign.id)' do
      subject.process(campaign)
      expect([:resque, :dialer_worker]).to have_queued(CalculateDialsJob).with(campaign.id)
    end
  end
end

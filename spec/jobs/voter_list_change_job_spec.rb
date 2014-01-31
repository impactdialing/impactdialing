require 'spec_helper'

require 'resque/errors'

describe VoterListChangeJob do
  let(:subject){ VoterListChangeJob }
  let(:voter) do
    create(:voter)
  end
  let(:voter_list) do
    voter.voter_list
  end
  let(:enabled){ false }
  it 'properly requeues itself if the worker is stopped during a run' do
    Resque.should_receive(:enqueue).with(subject, voter_list.id, enabled)
    Voter.stub_chain(:where, :update_all){ raise Resque::TermException, 'KILL' }
    subject.perform(voter_list.id, false)
  end
end


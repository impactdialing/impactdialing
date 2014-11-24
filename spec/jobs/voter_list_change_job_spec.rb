require 'spec_helper'

require 'resque/errors'

describe VoterListChangeJob do
  let(:subject){ VoterListChangeJob }
  let(:voter_list) do
    create(:voter_list)
  end
  let(:new_voter_list) do
    create(:voter_list, {
      csv_to_system_map: {
        'VANID' => 'custom_id',
        'FirstName' => 'first_name',
        'LastName' => 'last_name',
        'Phone' => 'phone'
      },
      s3path: "test/uploads/voter_list/custom-id-numbers.csv"
    })
  end
  let(:voters) do
    create_list(:voter, 3, {
      first_name: 'Frank',
      last_name: 'Moody',
      voter_list: voter_list
    })
  end
  let(:enabled){ false }
  before do
    voter_list.voters = voters
    voter_list.save!
  end
  after do
    VoterList.destroy_all
    Voter.destroy_all
  end

  shared_examples 'enabled/disabled voter list change' do
    let(:blocked){ false }

    before do
      bits = []
      bits << :list unless enabled
      Voter.update_all(enabled: Voter.bitmask_for_enabled(*bits))
      if blocked
        bits << :blocked
        Voter.first.update_attributes!(enabled: Voter.bitmask_for_enabled(*bits))
      end
    end
    context 'Voter.first#enabled :blocked bit is set' do
      let(:blocked){ true }
      it 'preserves the :blocked bit' do
        subject.perform(voter_list.id, enabled)
        expect(Voter.with_enabled(:blocked).count).to eq 1
      end
    end

    context 'Voter#enabled :blocked bit is not set' do
      it 'preserves the :blocked bit' do
        subject.perform(voter_list.id, enabled)
        expect(Voter.with_enabled(:blocked).count).to be_zero
      end
    end
  end

  context 'VoterList#enabled is true' do
    let(:enabled){ true }

    it 'sets Voter#enabled :list bit' do
      subject.perform(voter_list.id, enabled)
      expect(Voter.with_enabled(:list).count).to eq voter_list.voters.count
    end

    it_behaves_like 'enabled/disabled voter list change'
  end

  context 'VoterList#enabled is false' do
    let(:enabled){ false }

    it 'unsets Voter#enabled :list bit' do
      subject.perform(voter_list.id, enabled)
      expect(Voter.without_enabled(:list).count).to eq voter_list.voters.count
    end

    it_behaves_like 'enabled/disabled voter list change'
  end

  it 'refreshes the available voter queue' do
    dial_queue = double('DialQueue')
    allow(CallFlow::DialQueue).to receive(:new){ dial_queue }
    expect(dial_queue).to receive(:refresh).with(:available)
    subject.perform(voter_list.id, enabled)
  end

  it 'properly requeues itself if the worker is stopped during a run' do
    expect(Resque).to receive(:enqueue).with(subject, voter_list.id, enabled)
    allow(VoterList).to receive(:find){ raise Resque::TermException, 'TERM' }
    subject.perform(voter_list.id, enabled)
  end

  context 'Deadlock victims' do
    let(:msg){ 'Mysql2::Error: Deadlock found when trying to get lock; try restarting transaction: UPDATE `voters` SET `enabled` = 0 WHERE `voters`.`id` IN (123, 321)' }

    let(:mailer) do
      double('ExceptionMailer', {
        notify_if_deadlock_detected: nil,
        deadlock_detected?: true
      })
    end
    before do
      allow(VoterList).to receive(:find){ raise ActiveRecord::StatementInvalid, msg }
      allow(Resque).to receive(:enqueue).with(subject, voter_list.id, anything)
      allow(ExceptionMailer).to receive(:new){ mailer }
    end

    it 'are requeued' do
      expect(Resque).to receive(:enqueue).with(subject, voter_list.id, anything)
      subject.perform(voter_list.id, enabled)
    end

    it 'emails the innodb status' do
      expect(mailer).to receive(:notify_if_deadlock_detected)
      subject.perform(voter_list.id, enabled)
    end
  end

  context 'other exceptions' do
    before do
      allow(VoterList).to receive(:find){ raise ActiveRecord::StatementInvalid, "Syntax error" }
    end
    it 'fall through' do
      expect{subject.perform(voter_list.id, enabled)}.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end

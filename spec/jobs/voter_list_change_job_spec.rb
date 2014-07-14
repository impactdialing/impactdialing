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

  it 'properly requeues itself if the worker is stopped during a run' do
    expect(Resque).to receive(:enqueue).with(subject, voter_list.id, enabled)
    Voter.stub_chain(:where, :update_all){ raise Resque::TermException, 'TERM' }
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
      Voter.stub_chain(:where, :update_all){ raise ActiveRecord::StatementInvalid, msg }
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
      Voter.stub_chain(:where, :update_all){ raise ActiveRecord::StatementInvalid, "Syntax error" }
    end
    it 'fall through' do
      expect{subject.perform(voter_list.id, enabled)}.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end

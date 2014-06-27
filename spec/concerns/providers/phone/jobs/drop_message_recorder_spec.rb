require 'spec_helper'

describe Providers::Phone::Jobs::DropMessageRecorder do
  let(:recording){ create(:recording) }
  let(:campaign){ create(:power, {recording: recording}) }
  let(:caller){ create(:caller, {campaign: campaign}) }
  let(:caller_session){ create(:webui_caller_session, {caller: caller}) }
  let(:voter){ create(:voter, {campaign: campaign}) }
  let(:call_attempt){ create(:call_attempt, {voter: voter, campaign: campaign, caller_session: caller_session}) }
  let(:call){ create(:call, {call_attempt: call_attempt}) }
  subject{ Providers::Phone::Jobs::DropMessageRecorder.new }

  it 'stores recording id with the CallAttempt' do
    subject.perform(call.id, 1)

    call_attempt.reload.recording_id.should eq recording.id
  end

  it 'stores whether recording was delivered manually or not' do
    call_attempt.recording_delivered_manually?.should be_false
    subject.perform(call.id, 1)

    call_attempt.reload.recording_delivered_manually?.should be_true
  end

  it 'stores the recording id with the Voter' do
    subject.perform(call.id, 1)

    voter.reload.voicemail_history.should eq recording.id.to_s
  end
end
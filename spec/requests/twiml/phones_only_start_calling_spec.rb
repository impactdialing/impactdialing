require 'rails_helper'

describe 'Phone-only caller dials TwiML app number' do
  let(:caller){ create(:caller, is_phones_only: true) }
  before do
    Redis.new.flushall
    caller.campaign.update_attribute(:end_time, caller.campaign.start_time)
  end

  it 'POSTs to callin/create & asks for PIN' do
    post callin_caller_path
    expect(response.body).to include 'Please enter your pin and then press star.'
  end

  context 'Incorrect PIN entered' do
    it 'asks for PIN again' do
      post identify_caller_path, {Digits: '1234', attempt: 1}
      expect(response.body).to include 'Incorrect pin. Please enter your pin and then press star.'
    end

    it 'hangs-up after 3 incorrect PIN messages' do
      post identify_caller_path, {Digits: '1234', attempt: 3}
      expect(response.body).to include 'Incorrect pin.'
      expect(response.body).to include '<Hangup/>'
    end
  end

  context 'Correct PIN entered' do
    it 'creates a new phones only caller session' do
      expect{
        post identify_caller_path, {Digits: caller.pin, attempt: 1}
      }.to change{ PhonesOnlyCallerSession.count }.by(1)
    end
    it 'caches phones-only script questions' do
      post identify_caller_path, {Digits: caller.pin, attempt: 2}
      expect(response).to be_success
      expect(resque_jobs(:persist_jobs)).to include({
        'class' => 'CachePhonesOnlyScriptQuestions',
        'args' => [caller.campaign.script_id, 'seed']
      })
    end

    it 'prompts the caller to have instructions read or start calling' do
      post identify_caller_path, {Digits: caller.pin, attempt: 3}
      expect(response.body).to include I18n.t(:caller_instruction_choice)
    end
  end
end

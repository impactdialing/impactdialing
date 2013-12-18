require "spec_helper"

describe RedisCallerSession do
  subject{ RedisCallerSession }

  it "should set options" do
    RedisCallerSession.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    result = RedisCallerSession.get_request_params(1)
    JSON.parse(result).should eq({"digit"=>1, "question_number"=>2, "question_id"=>3})
  end

  it "should get digit" do
    RedisCallerSession.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    RedisCallerSession.digit(1).should eq(1)
  end

  it "should get question number" do
    RedisCallerSession.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    RedisCallerSession.question_number(1).should eq(2)
  end

  it "should get question id" do
    RedisCallerSession.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    RedisCallerSession.question_id(1).should eq(3)
  end

  describe 'manage an active transfer flag' do
    let(:session_key){ 'session-key.abc123' }
    before do
      subject.deactivate_transfer(session_key)
    end
    after do
      subject.deactivate_transfer(session_key)
    end
    describe '#activate_transfer(caller_session_key)' do
      it 'sets caller_sessions.#{caller_session_key}.active_transfer = "1"' do
        subject.activate_transfer(session_key)
        subject.active_transfer(session_key).should eq '1'
      end
    end

    describe '#deactivate_transfer(caller_session_key)' do
      it 'deletes caller_sessions.#{caller_session_key}.active_transfer' do
        subject.deactivate_transfer(session_key)
        subject.active_transfer(session_key).should be_nil
      end
    end

    describe '#active_transfer(caller_session_key)' do
      it 'returns the current value of caller_sessions.#{caller_session_key}.active_transfer' do
        subject.active_transfer(session_key).should be_nil

        subject.activate_transfer(session_key)
        subject.active_transfer(session_key).should eq '1'
      end
    end

    describe '#active_transfer?(caller_session_key)' do
      it 'returns true when caller_sessions.#{caller_session_key}.active_transfer == "1"' do
        subject.activate_transfer(session_key)
        subject.active_transfer?(session_key).should be_true
      end

      it 'returns false when caller_sessions.#{caller_session_key}.active_transfer != "1"' do
        subject.active_transfer?(session_key).should be_false
        subject.active_transfer(session_key).should be_nil
      end
    end
  end
end

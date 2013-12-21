require "spec_helper"

describe RedisCallerSession do
  subject{ RedisCallerSession }

  it "should set options" do
    subject.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    result = subject.get_request_params(1)
    JSON.parse(result).should eq({"digit"=>1, "question_number"=>2, "question_id"=>3})
  end

  it "should get digit" do
    subject.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    subject.digit(1).should eq(1)
  end

  it "should get question number" do
    subject.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    subject.question_number(1).should eq(2)
  end

  it "should get question id" do
    subject.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    subject.question_id(1).should eq(3)
  end

  describe 'manage a active transfer party counts' do
    let(:caller_session_key){ 'caller-session-key' }
    let(:transfer_session_key){ 'transfer-session-key' }
    let(:party_count_key) do
      subject.active_transfer_key(transfer_session_key)
    end
    let(:transfer_cache_key) do
      subject._active_transfer_session_key(caller_session_key)
    end
    after do
      subject.deactivate_transfer(caller_session_key)
    end
    describe '.activate_transfer(caller_session_key, transfer_session_key)' do
      before do
        subject.activate_transfer(caller_session_key, transfer_session_key)
      end
      it 'sets active_transfer_key(transfer_session_key) = -1' do
        subject.redis.get(party_count_key).should eq "-1"
      end
      it 'sets _active_transfer_session_key(caller_session_key) = #{transfer_session_key}' do
        subject.redis.get(transfer_cache_key).should eq transfer_session_key
      end
    end

    describe '.deactivate_transfer(caller_session_key)' do
      before do
        subject.deactivate_transfer(caller_session_key)
      end
      it 'deletes active_transfer_key(transfer_session_key)' do
        subject.redis.get(party_count_key).should be_nil
      end
      it 'deletes _active_transfer_session_key(caller_session_key)' do
        subject.redis.get(transfer_cache_key).should be_nil
      end
    end

    describe '.add_party(transfer_session_key)' do
      it 'increments the party counter' do
        subject.activate_transfer(caller_session_key, transfer_session_key)
        subject.redis.get(party_count_key).should eq "-1"

        subject.add_party(transfer_session_key)
        subject.redis.get(party_count_key).should eq "0"

        subject.add_party(transfer_session_key)
        subject.redis.get(party_count_key).should eq "1"
      end
    end

    describe '.remove_party(transfer_session_key)' do
      it 'decrements the party counter' do
        subject.activate_transfer(caller_session_key, transfer_session_key)
        subject.redis.get(party_count_key).should eq "-1"

        subject.add_party(transfer_session_key)
        subject.add_party(transfer_session_key)
        subject.add_party(transfer_session_key)
        subject.redis.get(party_count_key).should eq "2"

        subject.remove_party(transfer_session_key)
        subject.redis.get(party_count_key).should eq "1"
      end
    end

    describe '.party_count(caller_session_key)' do
      it 'returns the current value of active_transfer_key(transfer_session_key)' do
        subject.redis.get(party_count_key).should be_nil
        subject.redis.get(transfer_cache_key).should be_nil

        subject.activate_transfer(caller_session_key, transfer_session_key)
        subject.party_count(transfer_session_key).should eq -1
      end
    end

    describe '.pause?(caller_session_key, from_transfer_session_key)' do
      let(:from_transfer_session_key){ nil }
      before do
        subject.activate_transfer(caller_session_key, transfer_session_key)
      end
      it 'returns true when party_count(transfer_session_key) is zero' do
        subject.add_party(transfer_session_key)
        subject.pause?(caller_session_key, from_transfer_session_key).should be_true
      end

      it 'returns true when transfer_session_key is nil' do
        subject.deactivate_transfer(caller_session_key)
        subject.pause?(caller_session_key, from_transfer_session_key).should be_true
      end

      it 'returns false when party_count(transfer_session_key) is NOT zero' do
        subject.pause?(caller_session_key, from_transfer_session_key).should be_false
        subject.redis.get(party_count_key).should eq "-1"

        3.times{ subject.add_party(transfer_session_key) }
        subject.pause?(caller_session_key, from_transfer_session_key).should be_false
      end
    end

    describe '.any_active_transfers?(caller_session_key)' do
      it 'returns true for freshly activated' do
        subject.activate_transfer(caller_session_key, transfer_session_key)
        subject.party_count(transfer_session_key).should eq -1
        subject.any_active_transfers?(caller_session_key).should be_true
      end

      it 'returns true for populated' do
        subject.activate_transfer(caller_session_key, transfer_session_key)

        subject.add_party(transfer_session_key) # => 0
        subject.add_party(transfer_session_key) # => 1
        subject.any_active_transfers?(caller_session_key).should be_true
      end

      it 'returns false when none are found or all are zero' do
        subject.any_active_transfers?(caller_session_key).should be_false

        subject.activate_transfer(caller_session_key, transfer_session_key)
        subject.add_party(transfer_session_key) # => 0
        subject.any_active_transfers?(caller_session_key).should be_false
      end
    end
  end
end

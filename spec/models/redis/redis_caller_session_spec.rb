require "spec_helper"

describe RedisCallerSession, :type => :model do
  subject{ RedisCallerSession }

  it "should set options" do
    subject.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    result = subject.get_request_params(1)
    expect(JSON.parse(result)).to eq({"digit"=>1, "question_number"=>2, "question_id"=>3})
  end

  it "should get digit" do
    subject.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    expect(subject.digit(1)).to eq(1)
  end

  it "should get question number" do
    subject.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    expect(subject.question_number(1)).to eq(2)
  end

  it "should get question id" do
    subject.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    expect(subject.question_id(1)).to eq(3)
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
        expect(subject.redis.get(party_count_key)).to eq "-1"
      end
      it 'sets _active_transfer_session_key(caller_session_key) = #{transfer_session_key}' do
        expect(subject.redis.get(transfer_cache_key)).to eq transfer_session_key
      end
    end

    describe '.deactivate_transfer(caller_session_key)' do
      before do
        subject.deactivate_transfer(caller_session_key)
      end
      it 'deletes active_transfer_key(transfer_session_key)' do
        expect(subject.redis.get(party_count_key)).to be_nil
      end
      it 'deletes _active_transfer_session_key(caller_session_key)' do
        expect(subject.redis.get(transfer_cache_key)).to be_nil
      end
    end

    describe '.add_party(transfer_session_key)' do
      it 'increments the party counter' do
        subject.activate_transfer(caller_session_key, transfer_session_key)
        expect(subject.redis.get(party_count_key)).to eq "-1"

        subject.add_party(transfer_session_key)
        expect(subject.redis.get(party_count_key)).to eq "0"

        subject.add_party(transfer_session_key)
        expect(subject.redis.get(party_count_key)).to eq "1"
      end
    end

    describe '.remove_party(transfer_session_key)' do
      it 'decrements the party counter' do
        subject.activate_transfer(caller_session_key, transfer_session_key)
        expect(subject.redis.get(party_count_key)).to eq "-1"

        subject.add_party(transfer_session_key)
        subject.add_party(transfer_session_key)
        subject.add_party(transfer_session_key)
        expect(subject.redis.get(party_count_key)).to eq "2"

        subject.remove_party(transfer_session_key)
        expect(subject.redis.get(party_count_key)).to eq "1"
      end
    end

    describe '.party_count(caller_session_key)' do
      it 'returns the current value of active_transfer_key(transfer_session_key)' do
        expect(subject.redis.get(party_count_key)).to be_nil
        expect(subject.redis.get(transfer_cache_key)).to be_nil

        subject.activate_transfer(caller_session_key, transfer_session_key)
        expect(subject.party_count(transfer_session_key)).to eq -1
      end
    end

    describe '.pause?(caller_session_key, from_transfer_session_key)' do
      let(:from_transfer_session_key){ nil }
      before do
        subject.activate_transfer(caller_session_key, transfer_session_key)
      end
      it 'returns true when party_count(transfer_session_key) is zero' do
        subject.add_party(transfer_session_key)
        expect(subject.pause?(caller_session_key, from_transfer_session_key)).to be_truthy
      end

      it 'returns true when transfer_session_key is nil' do
        subject.deactivate_transfer(caller_session_key)
        expect(subject.pause?(caller_session_key, from_transfer_session_key)).to be_truthy
      end

      it 'returns false when party_count(transfer_session_key) is NOT zero' do
        expect(subject.pause?(caller_session_key, from_transfer_session_key)).to be_falsey
        expect(subject.redis.get(party_count_key)).to eq "-1"

        3.times{ subject.add_party(transfer_session_key) }
        expect(subject.pause?(caller_session_key, from_transfer_session_key)).to be_falsey
      end
    end

    describe '.any_active_transfers?(caller_session_key)' do
      it 'returns true for freshly activated' do
        subject.activate_transfer(caller_session_key, transfer_session_key)
        expect(subject.party_count(transfer_session_key)).to eq -1
        expect(subject.any_active_transfers?(caller_session_key)).to be_truthy
      end

      it 'returns true for populated' do
        subject.activate_transfer(caller_session_key, transfer_session_key)

        subject.add_party(transfer_session_key) # => 0
        subject.add_party(transfer_session_key) # => 1
        expect(subject.any_active_transfers?(caller_session_key)).to be_truthy
      end

      it 'returns false when none are found or all are zero' do
        expect(subject.any_active_transfers?(caller_session_key)).to be_falsey

        subject.activate_transfer(caller_session_key, transfer_session_key)
        subject.add_party(transfer_session_key) # => 0
        expect(subject.any_active_transfers?(caller_session_key)).to be_falsey
      end
    end
  end
end

require 'rails_helper'

describe SimulatedCallAttempt do
  context '.from_call_attempt' do
    it 'initializes from a real call attempt object' do
      real_call_attempt = FactoryGirl.create(:answered_call_attempt)
      simulated_call_attempt = SimulatedCallAttempt.from_call_attempt(real_call_attempt)
      # simulated_call_attempt.ringing_length.should eq real_call_attempt.connecttime - real_call_attempt.created_at
      # since the move to the redis call flow, we aren't persisting data to calculate ringing length. we should change this, but for now, 10 seconds is a reasonable value to use across the board
      simulated_call_attempt.ringing_length.should eq 10
      simulated_call_attempt.conversation_length.should eq real_call_attempt.tDuration
      # simulated_call_attempt.wrapup_length.should eq real_call_attempt.wrapup_time - real_call_attempt.call_end
      # since the move to the redis call flow, we aren't persisting data to calculate wrapup length. we should change this, but for now, 5 seconds is a reasonable value to use across the board
      simulated_call_attempt.wrapup_length.should eq 5
    end

    it 'sets ringing_length to 15 if the call was not answered' do
      real_call_attempt = FactoryGirl.create(:call_attempt)
      simulated_call_attempt = SimulatedCallAttempt.from_call_attempt(real_call_attempt)
      simulated_call_attempt.ringing_length.should eq 15
    end
  end

  context '#new' do
    it 'initializes with state "idle"' do
      SimulatedCallAttempt.new.state.should eq 'idle'
    end

    it 'initializes with time_at_state 1' do
      SimulatedCallAttempt.new.time_at_state.should eq 1
    end
  end

  context '#answered?' do
    it 'is true if there is a conversation length' do
      SimulatedCallAttempt.new(conversation_length: 30).answered?.should be true
    end
  end

  context '#dial' do
    it 'changes its state to "ringing"' do
      simulated_call_attempt = SimulatedCallAttempt.new
      simulated_call_attempt.dial
      simulated_call_attempt.state.should eq 'ringing'
    end
  end

  context '#forward_one_second' do
    context 'while idle' do
      it 'increases its time in state by 1' do
        simulated_call_attempt = SimulatedCallAttempt.new
        simulated_call_attempt.state.should eq 'idle'
        lambda {simulated_call_attempt.forward_one_second}.should change(simulated_call_attempt, :time_at_state).by 1
      end

      it 'keeps its current state unless something else happens' do
        simulated_call_attempt = SimulatedCallAttempt.new
        simulated_call_attempt.state.should eq 'idle'
        lambda {simulated_call_attempt.forward_one_second}.should_not change(simulated_call_attempt, :state)
      end
    end

    context 'while ringing' do
      it 'increases its time in state by 1' do
        simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10)
        simulated_call_attempt.dial
        simulated_call_attempt.state.should eq 'ringing'
        lambda {simulated_call_attempt.forward_one_second}.should change(simulated_call_attempt, :time_at_state).by 1
      end

      it 'keeps its current state if the time_in_state is less than the ringing_length' do
        simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10)
        simulated_call_attempt.dial
        simulated_call_attempt.state.should eq 'ringing'
        lambda {simulated_call_attempt.forward_one_second}.should_not change(simulated_call_attempt, :state)
      end

      it 'switches from "ringing" to "answered" if the ringing_length is reached and the call is answered' do
        simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
        simulated_call_attempt.dial
        10.times {simulated_call_attempt.forward_one_second}
        simulated_call_attempt.state.should eq 'answered'
      end

      it 'switches from "ringing" to "idle" if the ringing_length is reached and the call was not answered' do
        simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10)
        simulated_call_attempt.dial
        10.times {simulated_call_attempt.forward_one_second}
        simulated_call_attempt.state.should eq 'idle'
      end
    end

    context 'while answered' do
      it 'increases its time in state by 1' do
        simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
        simulated_call_attempt.dial
        10.times {simulated_call_attempt.forward_one_second}
        simulated_call_attempt.state.should eq 'answered'
        lambda {simulated_call_attempt.forward_one_second}.should change(simulated_call_attempt, :time_at_state).by 1
      end

      it 'keeps its current state if the time_in_state is less than the conversation_length' do
        simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
        simulated_call_attempt.dial
        10.times {simulated_call_attempt.forward_one_second}
        simulated_call_attempt.state.should eq 'answered'
        lambda {simulated_call_attempt.forward_one_second}.should_not change(simulated_call_attempt, :state)
      end

      it 'switches from "answered" to "wrapup" when the conversation_length is reached' do
        simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
        simulated_call_attempt.dial
        10.times {simulated_call_attempt.forward_one_second}
        simulated_call_attempt.state.should eq 'answered'
        30.times {simulated_call_attempt.forward_one_second}
        simulated_call_attempt.state.should eq 'wrapup'
      end
    end

    context 'while in wrapup' do
      it 'increases its time in state by 1' do
        simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30, wrapup_length: 8)
        simulated_call_attempt.dial
        10.times {simulated_call_attempt.forward_one_second}
        30.times {simulated_call_attempt.forward_one_second}
        simulated_call_attempt.state.should eq 'wrapup'
        lambda {simulated_call_attempt.forward_one_second}.should change(simulated_call_attempt, :time_at_state).by 1
      end

      it 'keeps its current state if the time_in_state is less than the wrapup_length' do
        simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30, wrapup_length: 8)
        simulated_call_attempt.dial
        10.times {simulated_call_attempt.forward_one_second}
        30.times {simulated_call_attempt.forward_one_second}
        simulated_call_attempt.state.should eq 'wrapup'
        lambda {simulated_call_attempt.forward_one_second}.should_not change(simulated_call_attempt, :state)
      end
    end

    it 'switches from "wrapup" to "idle" when the wrapup_length is reached' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30, wrapup_length: 8)
      simulated_call_attempt.dial
      10.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.assign_caller(SimulatedCaller.new)
      simulated_call_attempt.state.should eq 'answered'
      30.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.state.should eq 'wrapup'
      8.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.state.should eq 'idle'
    end
  end

  context '#time_at_state' do
    it 'resets its time_at_state to 1 when it transitions from idel to ringing' do
      simulated_call_attempt = SimulatedCallAttempt.new
      simulated_call_attempt.dial
      simulated_call_attempt.time_at_state.should eq 1
    end

    it 'resets its time_at_state to 1 when it transitions from ringing to idle' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10)
      simulated_call_attempt.dial
      10.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.state.should eq 'idle'
      simulated_call_attempt.time_at_state.should eq 1
    end

    it 'resets its time_at_state to 1 when it transitions from ringing to answered' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
      simulated_call_attempt.dial
      10.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.state.should eq 'answered'
      simulated_call_attempt.time_at_state.should eq 1
    end

    it 'resets its time_at_state to 1 when it transitions from answered to wrapup' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
      simulated_call_attempt.dial
      10.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.state.should eq 'answered'
      simulated_call_attempt.time_at_state.should eq 1
      30.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.state.should eq 'wrapup'
      simulated_call_attempt.time_at_state.should eq 1
    end

    it 'resets its time_at_state to 1 when it transitions from wrapup to idle' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30, wrapup_length: 8)
      simulated_call_attempt.dial
      10.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.assign_caller(SimulatedCaller.new)
      simulated_call_attempt.state.should eq 'answered'
      simulated_call_attempt.time_at_state.should eq 1
      30.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.state.should eq 'wrapup'
      simulated_call_attempt.time_at_state.should eq 1
      8.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.state.should eq 'idle'
      simulated_call_attempt.time_at_state.should eq 1
    end

    it 'puts its caller back on hold when it transitions from wrapup to idle' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 1, conversation_length: 2, wrapup_length: 3)
      simulated_call_attempt.dial
      1.times {simulated_call_attempt.forward_one_second}
      simulated_caller = SimulatedCaller.new
      simulated_call_attempt.assign_caller(simulated_caller)
      expect {5.times {simulated_call_attempt.forward_one_second}}.to change(simulated_caller, :state). to('on_hold')
    end
  end

  context '#just_answered?' do
    it 'is true if in the answered state and time_at_state is 1' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
      simulated_call_attempt.dial
      10.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.just_answered?.should be true
    end

    it 'is false otherwise' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
      simulated_call_attempt.just_answered?.should be false
      simulated_call_attempt.dial
      11.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.just_answered?.should be false
    end
  end

  context '#abandon' do
    it 'switches from answered to idle' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
      simulated_call_attempt.dial
      10.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.abandon
      simulated_call_attempt.state.should eq 'idle'
    end

    it 'increases its abandon_count by 1' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
      simulated_call_attempt.dial
      10.times {simulated_call_attempt.forward_one_second}
      lambda {simulated_call_attempt.abandon}.should change(simulated_call_attempt, :abandon_count).by 1
    end
  end

  context '#dial_count' do
    it 'tells the number of times the call attempt has been dialed' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
      lambda {simulated_call_attempt.dial}.should change(simulated_call_attempt, :dial_count).by 1
    end
  end

  context '#answer_count' do
    it 'tells the number of times the call attempt has been answered' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
      simulated_call_attempt.dial
      9.times {simulated_call_attempt.forward_one_second}
      lambda {simulated_call_attempt.forward_one_second}.should change(simulated_call_attempt, :answer_count).by 1
    end
  end

  context '#reset_stats!' do
    it 'resets time_at_state to 1' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10)
      simulated_call_attempt.forward_one_second
      expect {simulated_call_attempt.reset_stats!}.to change(simulated_call_attempt, :time_at_state).to(1)
    end

    it 'resets dial_count to 0' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10)
      simulated_call_attempt.dial
      simulated_call_attempt.forward_one_second
      expect {simulated_call_attempt.reset_stats!}.to change(simulated_call_attempt, :dial_count).to(0)
    end

    it 'resets answer_count to 0' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
      simulated_call_attempt.dial
      10.times {simulated_call_attempt.forward_one_second}
      expect {simulated_call_attempt.reset_stats!}.to change(simulated_call_attempt, :answer_count).to(0)
    end

    it 'resets abandon_count to 0' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10, conversation_length: 30)
      simulated_call_attempt.dial
      10.times {simulated_call_attempt.forward_one_second}
      simulated_call_attempt.abandon
      expect {simulated_call_attempt.reset_stats!}.to change(simulated_call_attempt, :abandon_count).to(0)
    end

    it 'resets to the idle state' do
      simulated_call_attempt = SimulatedCallAttempt.new(ringing_length: 10)
      simulated_call_attempt.dial
      simulated_call_attempt.forward_one_second
      expect {simulated_call_attempt.reset_stats!}.to change(simulated_call_attempt, :state).to('idle')
    end
  end

  context 'assign_caller' do
    it 'changes the caller from on_hold to on_call' do
      simulated_call_attempt = SimulatedCallAttempt.new
      simulated_caller = SimulatedCaller.new
      expect {simulated_call_attempt.assign_caller(simulated_caller)}.to change(simulated_caller, :state). to('on_call')
    end
  end
end

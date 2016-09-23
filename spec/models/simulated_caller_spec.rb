require 'rails_helper'

describe SimulatedCaller do
  context '#new' do
    it 'initializes with state "on_hold"' do
      SimulatedCaller.new.state.should eq 'on_hold'
    end

    it 'initializes with 0 idle time' do
      SimulatedCaller.new.on_hold_time.should eq 0
    end

    it 'initializes with 0 on call time' do
      SimulatedCaller.new.on_call_time.should eq 0
    end
  end

  context '#take_call' do
    it 'changes its state to "on_call"' do
      sc = SimulatedCaller.new
      sc.take_call
      sc.state.should eq 'on_call'
    end
  end

  context '#forward_one_second' do
    context 'while on_hold' do
      it 'increases its on_hold_time by 1' do
        sc = SimulatedCaller.new
        lambda {sc.forward_one_second}.should change(sc, :on_hold_time).by 1
      end
    end

    context 'while on_call' do
      it 'increases its on_call_time by 1' do
        sc = SimulatedCaller.new
        sc.take_call
        lambda {sc.forward_one_second}.should change(sc, :on_call_time).by 1
      end
    end
  end

  context '#finish_call' do
    it 'goes back to on hold' do
      sc = SimulatedCaller.new
      sc.take_call
      expect {sc.finish_call}.to change(sc, :state).to('on_hold')
    end
  end

  context '#reset_stats!' do
    it 'resets its on_hold_time to 0' do
      sc = SimulatedCaller.new
      sc.forward_one_second
      expect {sc.reset_stats!}.to change(sc, :on_hold_time).to(0)
    end

    it 'resets its on_call_time to 0' do
      sc = SimulatedCaller.new
      sc.take_call
      sc.forward_one_second
      expect {sc.reset_stats!}.to change(sc, :on_call_time).to(0)
    end

    it 'resets to the idle state' do
      sc = SimulatedCaller.new
      sc.take_call
      sc.forward_one_second
      expect {sc.reset_stats!}.to change(sc, :state).to('on_hold')
    end
  end
end

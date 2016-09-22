require 'rails_helper'

describe SimulatedValues do
  context '#number_of_callers_on_call' do
    it 'counts the number of caller sessions currently on call' do
      campaign = FactoryGirl.create(:campaign)
      3.times {FactoryGirl.create(:caller_session, campaign: campaign,
                                        on_call: true,
                                        caller: FactoryGirl.create(:caller))}
      simulated_values = SimulatedValues.new(campaign: campaign)
      simulated_values.number_of_callers_on_call.should eq 3
    end
  end

  context '#simulated_callers' do
    it 'creates simulated callers for each caller currently on call' do
      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      simulated_callers = simulated_values.simulated_callers(3)
      simulated_callers.first.should be_an_instance_of SimulatedCaller
      simulated_callers.length.should eq 3
    end
  end

  context '#recent_call_attempts' do
    it 'returns an array of the call attempts in the past 10 minutes' do
      campaign = FactoryGirl.create(:campaign)
      4.times {FactoryGirl.create(:call_attempt, campaign: campaign,
                                       created_at: Time.now,
                                       caller: FactoryGirl.create(:caller))}
      simulated_values = SimulatedValues.new(campaign: campaign)
      simulated_values.recent_call_attempts.sample.should be_an_instance_of CallAttempt
      simulated_values.recent_call_attempts.length.should eq 4
    end

    it 'does not include call attempts older than 30 minutes' do
      campaign = FactoryGirl.create(:campaign)
      3.times {FactoryGirl.create(:call_attempt, campaign: campaign,
                                      created_at: Time.now,
                                      caller: FactoryGirl.create(:caller))}
      1.times {FactoryGirl.create(:call_attempt, campaign: campaign,
                                      created_at: Time.now - 32.minutes,
                                      caller: FactoryGirl.create(:caller))}
      simulated_values = SimulatedValues.new(campaign: campaign)
      simulated_values.recent_call_attempts.length.should eq 3
    end

    # it 'does not get more than 1,000 call attempts' do
    #   campaign = FactoryGirl.create(:campaign)
    #   1001.times {FactoryGirl.create(:call_attempt, campaign: campaign,
    #                                      created_at: Time.now,
    #                                      caller: FactoryGirl.create(:caller))}
    #   simulated_values = SimulatedValues.new(campaign: campaign)
    #   simulated_values.simulated_call_attempts.length.should eq 1000
    # end
  end

  # context '#simulated_call_attempts' do
  #   it 'creates simulated call attempts for each call attempt' do
  #     call_attempts = []
  #     4.times {call_attempts << double("call attempt")}
  #
  #     simulated_call_attempt_class = double("simulated call attempt class")
  #     simulated_call_attempt_class.should_receive(:class).and_return(SimulatedCallAttempt)
  #     SimulatedCallAttempt.stub(:from_call_attempt) {simulated_call_attempt_class}
  #
  #     simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
  #     simulated_call_attempts = simulated_values.simulated_call_attempts(call_attempts)
  #     simulated_call_attempts.sample.should be_an_instance_of SimulatedCallAttempt
  #     simulated_call_attempts.length.should eq 4
  #   end
  # end

  context '#answer_rate' do
    it 'returns the ratio of the dialed call attempts to the answered call attempts' do
      simulated_call_attempts = []

      unanswered_call_attempt = double("unanswered call attempt")
      15.times do
        uca = unanswered_call_attempt.dup
        simulated_call_attempts << uca
        uca.should_receive(:answered?).and_return(false)
      end

      answered_call_attempt = double("answered call attempt")
      5.times do
        aca = answered_call_attempt.dup
        simulated_call_attempts << aca
        aca.should_receive(:answered?).and_return(true)
      end

      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      simulated_values.answer_rate(simulated_call_attempts).should eq 4
    end

    it 'returns 1 if there were no dials made' do
      campaign = FactoryGirl.create(:campaign)
      simulated_values = SimulatedValues.new(campaign: campaign)
      simulated_call_attempts = simulated_values.simulated_call_attempts(simulated_values.recent_call_attempts)
      simulated_values.answer_rate(simulated_call_attempts).should eq 1
    end
  end

  context '#longest_wrapup' do
    it 'returns the longest wrapup time' do
      shorter_simulated_call_attempt = double("shorter simulated call attempt")
      longer_simulated_call_attempt = double("longer simulated call attempt")
      simulated_call_attempts = [shorter_simulated_call_attempt, longer_simulated_call_attempt]
      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))

      shorter_simulated_call_attempt.should_receive(:wrapup_length).and_return(10)
      longer_simulated_call_attempt.should_receive(:wrapup_length).and_return(20)
      simulated_values.longest_wrapup(simulated_call_attempts).should eq 20
    end

    it 'does not choke if the wrapup time is nil' do
      nil_wrapup_simulated_call_attempt = double("nil wrapup simulated call attempt")
      simulated_call_attempt = double("simulated call attempt")
      simulated_call_attempts = [nil_wrapup_simulated_call_attempt, simulated_call_attempt]
      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))

      nil_wrapup_simulated_call_attempt.should_receive(:wrapup_length).and_return(nil)
      simulated_call_attempt.should_receive(:wrapup_length).and_return(20)
      simulated_values.longest_wrapup(simulated_call_attempts).should eq 20
    end
  end

  context '#current_wrapup' do
    it 'returns the longest wrapup divided by the current increment divided by the total increment' do
      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      longest_wrapup = 12
      current_increment = 5
      total_increment = 10
      simulated_values.current_wrapup(longest_wrapup, current_increment, total_increment).should eq longest_wrapup.to_f * (current_increment.to_f / total_increment.to_f)
    end
  end

  context '#current_dials' do
    it 'returns the current increment of the answer_rate' do
      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      answer_rate = 4
      current_increment = 5
      total_increment = 10
      simulated_values.current_dials(answer_rate, current_increment, total_increment).should eq((answer_rate.to_f * (current_increment.to_f / total_increment.to_f)))
    end
  end

  context '#assign_answered_calls_to_callers' do
    it 'assigns an answered call to a caller' do
      simulated_caller = double("simulated caller")
      simulated_callers = [simulated_caller]
      simulated_call_attempt = double("simulated_call_attempt")
      simulated_call_attempts = [simulated_call_attempt]
      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))

      simulated_caller.should_receive(:state).and_return('on_hold')
      simulated_call_attempt.should_receive(:just_answered?).and_return(true)
      simulated_call_attempt.should_receive(:assign_caller)
      simulated_values.assign_answered_calls_to_callers(simulated_callers, simulated_call_attempts)
    end

    it 'abandons an answered call if no caller is on_hold' do
      simulated_caller = double("simulated caller")
      simulated_callers = [simulated_caller]
      simulated_call_attempt = double("answered simulated call attempt")
      simulated_call_attempts = [simulated_call_attempt]
      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))

      simulated_caller.should_receive(:state).and_return(:on_call)
      simulated_call_attempt.should_receive(:just_answered?).and_return(true)
      simulated_call_attempt.should_receive(:abandon)
      simulated_values.assign_answered_calls_to_callers(simulated_callers, simulated_call_attempts)
    end
  end

  context '#lines_to_dial' do
    it 'counts the number of on_hold callers, multiplies it by the best_dials, and subtracts the ringing lines' do
      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))

      on_hold_caller = double('on_hold caller')
      on_hold_caller.should_receive(:state).and_return('on_hold')
      on_call_caller = double('on_call caller')
      on_call_caller.should_receive(:state).and_return('on_call')
      simulated_callers = [on_hold_caller, on_call_caller]

      ringing_simulated_call_attempt = double('ringing simulated call attempt')
      ringing_simulated_call_attempt.should_receive(:state).and_return('ringing')
      idle_simulated_call_attempt = double('idle simulated call attempt')
      idle_simulated_call_attempt.should_receive(:state).and_return('idle')
      simulated_call_attempts = [ringing_simulated_call_attempt, idle_simulated_call_attempt]

      best_dials = 4

      simulated_values.lines_to_dial(simulated_callers, simulated_call_attempts, best_dials).should eq 3
    end

    it 'returns 0 if the calculation is negative'
  end

  context '#make_dials' do
    it 'calls #dial on lines_to_dial simulated call attempts' do
      simulated_call_attempts = []
      5.times do
        simulated_call_attempt = double('simulated_call_attempt')
        simulated_call_attempt.should_receive(:state).and_return('idle')
        simulated_call_attempt.should_receive(:dial)
        simulated_call_attempts << simulated_call_attempt
      end

      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      simulated_values.make_dials(5, simulated_call_attempts)
    end

    it 'does not call dial on a ringing, answered, or wrapup call attempt' do
      ringing_call_attempt = double('ringing call attempt')
      ringing_call_attempt.should_receive(:state).and_return(:ringing)
      ringing_call_attempt.should_not_receive(:dial)

      answered_call_attempt = double('answered call attempt')
      answered_call_attempt.should_receive(:state).and_return(:answered)
      answered_call_attempt.should_not_receive(:dial)

      wrapup_call_attempt = double('wrapup call attempt')
      wrapup_call_attempt.should_receive(:state).and_return(:wrapup)
      wrapup_call_attempt.should_not_receive(:dial)

      simulated_call_attempts = [ringing_call_attempt, answered_call_attempt, wrapup_call_attempt]

      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      simulated_values.make_dials(3, simulated_call_attempts)
    end
  end

  context '#acceptable_abandon_rate_not_exceeded?' do
    it 'returns true if the simulated abandon rate is less than the acceptable abandon rate' do
      simulated_call_attempts = []

      abandoned_call_attempt = double('abandoned call attempt')
      abandoned_call_attempt.should_receive(:abandon_count).and_return(1)
      abandoned_call_attempt.should_receive(:answer_count).and_return(1)
      simulated_call_attempts << abandoned_call_attempt

      4.times do
        not_abandoned_call_attempt = double('not abandoned call attempt')
        not_abandoned_call_attempt.should_receive(:abandon_count).and_return(0)
        not_abandoned_call_attempt.should_receive(:answer_count).and_return(1)
        simulated_call_attempts << not_abandoned_call_attempt
      end

      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))

      acceptable_abandon_rate = 0.3
      simulated_values.acceptable_abandon_rate_not_exceeded?(simulated_call_attempts, acceptable_abandon_rate).should be true
    end

    it 'returns false if the simulated abandon rate is greater than the acceptable abandon rate' do
      simulated_call_attempts = []

      abandoned_call_attempt = double('abandoned call attempt')
      abandoned_call_attempt.should_receive(:abandon_count).and_return(1)
      abandoned_call_attempt.should_receive(:answer_count).and_return(1)
      simulated_call_attempts << abandoned_call_attempt

      4.times do
        not_abandoned_call_attempt = double('not abandoned call attempt')
        not_abandoned_call_attempt.should_receive(:abandon_count).and_return(0)
        not_abandoned_call_attempt.should_receive(:answer_count).and_return(1)
        simulated_call_attempts << not_abandoned_call_attempt
      end

      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))

      acceptable_abandon_rate = 0.1
      simulated_values.acceptable_abandon_rate_not_exceeded?(simulated_call_attempts, acceptable_abandon_rate).should be false
    end
  end

  context '#utilization' do
    it 'sums the on call time and divides it by the sum of the on call time and the on hold time for all the callers' do
      simulated_callers = []
      2.times do
        simulated_caller = double('simulated caller')
        simulated_caller.should_receive(:on_call_time).and_return(7)
        simulated_caller.should_receive(:on_hold_time).and_return(3)
        simulated_callers << simulated_caller
      end
      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      simulated_values.utilization(simulated_callers).should eq 0.7
    end
  end

  context '#simulate!' do
    it 'moves simulated callers forward one second the number of seconds of the simulation length' do
      simulation_length = 3

      simulated_callers = []
      2.times do
        simulated_caller = double('simulated caller')
        simulated_caller.should_receive(:state).exactly(simulation_length * 2).times.and_return(:on_hold)
        simulated_caller.should_receive(:forward_one_second).exactly(simulation_length).times
        simulated_callers << simulated_caller
      end

      simulated_call_attempts = []
      lines_to_dial = 4
      current_wrapup = 10

      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      simulated_values.simulate!(simulated_callers, simulated_call_attempts, lines_to_dial, current_wrapup, simulation_length)
    end

    it 'moves simulated call attempts forward one second the number of seconds of the simulation length' do
      simulation_length = 3

      simulated_call_attempts = []
      2.times do
        simulated_call_attempt = double('simulated call attempt')
        simulated_call_attempt.should_receive(:state).at_least(1).times
        simulated_call_attempt.should_receive(:just_answered?).at_least(1).times
        simulated_call_attempt.should_receive(:forward_one_second).exactly(simulation_length).times
        simulated_call_attempts << simulated_call_attempt
      end

      simulated_callers = []
      lines_to_dial = 4
      current_wrapup = 10

      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      simulated_values.simulate!(simulated_callers, simulated_call_attempts, lines_to_dial, current_wrapup, simulation_length)
    end

    it 'calls #make_dials the number of seconds of the simulation length' do
      simulation_length = 3
      simulated_callers = []
      simulated_call_attempts = []
      lines_to_dial = 4
      current_wrapup = 10

      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      simulated_values.should_receive(:make_dials).exactly(simulation_length).times
      simulated_values.simulate!(simulated_callers, simulated_call_attempts, lines_to_dial, current_wrapup, simulation_length)
    end

    it 'calls #assign_answered_calls_to_callers the number of seconds of the simulation length' do
      simulation_length = 3
      simulated_callers = []
      simulated_call_attempts = []
      lines_to_dial = 4
      current_wrapup = 10

      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      simulated_values.should_receive(:assign_answered_calls_to_callers).exactly(simulation_length).times
      simulated_values.simulate!(simulated_callers, simulated_call_attempts, lines_to_dial, current_wrapup, simulation_length)
    end
  end

  context '#set_default_best_values' do
    it 'should set best dials to 1' do
      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      longest_wrapup = 25
      simulated_values.set_default_best_values(longest_wrapup)
      simulated_values.best_dials.should eq 1
    end

    it 'should set best_wrapup to longest wrapup' do
      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      longest_wrapup = 25
      simulated_values.set_default_best_values(longest_wrapup)
      simulated_values.best_wrapup_time.should eq longest_wrapup
    end

    it 'should set best_utilization to 0' do
      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      longest_wrapup = 25
      simulated_values.set_default_best_values(longest_wrapup)
      simulated_values.best_utilization.should eq 0
    end
  end

  context '#update_best_parameters!' do
    it 'updates @best_dials and @best_wrapup if the simulation produced the best utilization so far' do
      simulated_callers = []
      simulated_call_attempts = []
      acceptable_abandon_rate = 0.03
      current_dials = 2
      current_wrapup = 12
      longest_wrapup = 30

      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      simulated_values.should_receive(:acceptable_abandon_rate_not_exceeded?).and_return(true)
      simulated_values.should_receive(:utilization).and_return(1)

      simulated_values.set_default_best_values(longest_wrapup)

      simulated_values.update_best_parameters!(simulated_callers, simulated_call_attempts, acceptable_abandon_rate, current_dials, current_wrapup)
      simulated_values.best_dials.should eq 2
      simulated_values.best_wrapup_time.should eq 12
      simulated_values.best_utilization.should eq 1
    end
  end

  context '#reset_simulated_caller_stats' do
    it 'resets the stats of each simulated caller' do
      simulated_callers = []
      2.times do
        simulated_caller = double('simulated caller')
        simulated_caller.should_receive(:reset_stats!)
        simulated_callers << simulated_caller
      end

      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      simulated_values.reset_simulated_caller_stats(simulated_callers)
    end
  end

  context '#reset_simulated_call_attempts_stats' do
    it 'resets the stats of each simulated call attempt' do
      simulated_call_attempts = []
      2.times do
        simulated_call_attempt = double('simulated attempt')
        simulated_call_attempt.should_receive(:reset_stats!)
        simulated_call_attempts << simulated_call_attempt
      end

      simulated_values = SimulatedValues.new(campaign: FactoryGirl.create(:campaign))
      simulated_values.reset_simulated_call_attempt_stats(simulated_call_attempts)
    end
  end
end

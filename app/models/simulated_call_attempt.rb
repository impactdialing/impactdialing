class SimulatedCallAttempt
  attr_reader :ringing_length, :conversation_length, :wrapup_length, :state
  attr_accessor :time_at_state, :dial_count, :answer_count, :abandon_count, :simulated_caller

  state_machine :state, :initial => :idle do
    event :dial do
      transition :idle => :ringing
    end

    event :abandon do
      transition :answered => :idle
    end

    event :forward_one_second do
      transition :ringing  => :ringing,  :if => lambda {|sca| sca.time_at_state < sca.ringing_length}
      transition :ringing  => :idle,     :if => lambda {|sca| !sca.answered? && sca.time_at_state == sca.ringing_length}
      transition :ringing  => :answered, :if => lambda {|sca| sca.answered? && sca.time_at_state == sca.ringing_length}
      transition :answered => :answered, :if => lambda {|sca| sca.time_at_state < sca.conversation_length}
      transition :answered => :wrapup,   :if => lambda {|sca| sca.time_at_state == sca.conversation_length}
      transition :wrapup   => :wrapup,   :if => lambda {|sca| sca.time_at_state < sca.wrapup_length}
      transition :wrapup   => :idle,     :if => lambda {|sca| sca.time_at_state == sca.wrapup_length}
      transition :idle     => :idle
    end

    after_transition :idle => :idle, :answered => :answered, :ringing => :ringing, :wrapup => :wrapup do |sca, transition|
      sca.time_at_state += 1
    end

    after_transition :idle => :ringing do |sca, transition|
      sca.time_at_state = 1
      sca.dial_count += 1
    end

    after_transition :ringing => :answered do |sca, transition|
      sca.time_at_state = 1
      sca.answer_count += 1
    end

    after_transition :ringing => :idle do |sca, transition|
      sca.time_at_state = 1
    end

    after_transition :answered => :wrapup do |sca, transition|
      sca.time_at_state = 1
    end

    after_transition :wrapup => :idle do |sca, transition|
      sca.time_at_state = 1
      sca.simulated_caller.finish_call
    end

    after_transition :answered => :idle do |sca, transition|
      sca.abandon_count += 1
    end
  end

  def initialize(options = {})
    @ringing_length = options[:ringing_length]
    @conversation_length = options[:conversation_length]
    @wrapup_length = options[:wrapup_length]
    @time_at_state = 1
    @dial_count = 0
    @answer_count = 0
    @abandon_count = 0
    super()
  end

  def self.from_call_attempt(real_call_attempt)
    if real_call_attempt.tDuration
      ringing_length = 10
    else
      ringing_length = 15
    end

    if real_call_attempt.tDuration
      conversation_length = real_call_attempt.tDuration
    end

    wrapup_length = 5

    SimulatedCallAttempt.new(ringing_length: ringing_length,
                             conversation_length: conversation_length,
                             wrapup_length: wrapup_length)
  end

  def answered?
    @conversation_length.to_i > 0
  end

  def just_answered?
    self.state == 'answered' && self.time_at_state == 1
  end

  def assign_caller(simulated_caller)
    self.simulated_caller = simulated_caller
    simulated_caller.take_call
  end

  def reset_stats!
    @time_at_state = 1
    @dial_count = 0
    @answer_count = 0
    @abandon_count = 0
    @caller = nil
    self.state = 'idle'
  end
end

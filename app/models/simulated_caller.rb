class SimulatedCaller
  attr_accessor :on_hold_time, :on_call_time

  state_machine :state, :initial => :on_hold do
    event :forward_one_second do
      transition :on_hold => :on_hold, :if => lambda {|sc| sc.state == 'on_hold'}
      transition :on_call => :on_call, :if => lambda {|sc| sc.state == 'on_call'}
    end

    after_transition :on_hold => :on_hold do |sc, transition|
      sc.on_hold_time += 1
    end

    after_transition :on_call => :on_call do |sc, transition|
      sc.on_call_time += 1
    end

    event :take_call do
      transition :on_hold => :on_call
    end

    event :finish_call do
      transition :on_call => :on_hold
    end
  end

  def initialize
    @on_hold_time = 0
    @on_call_time = 0
    super()
  end

  def reset_stats!
    @on_hold_time = 0
    @on_call_time = 0
    self.state = 'on_hold'
  end
end

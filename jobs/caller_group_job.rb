require 'resque-loner'

class CallerGroupJob
  include Resque::Plugins::UniqueJob
  @queue = :background_worker

  def self.perform(caller_group_id)
    caller_group = CallerGroup.find(caller_group_id)
    caller_group.reassign_in_background
  end
end

module ReportsHelper

  module Utilization
    def time_logged_in(from, to)
      @time_logged_in ||= self.caller_sessions.between(from, to + 1.day).sum('TIMESTAMPDIFF(SECOND ,starttime,endtime)')
      round_for_utilization(@time_logged_in)
    end

    def time_on_call(from, to)
      @time_on_call ||= self.call_attempts.between(from, to + 1.day).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('TIMESTAMPDIFF(SECOND ,connecttime,call_end)')
      round_for_utilization(@time_on_call)
    end

    def time_in_wrapup(from, to)
      @time_in_wrapup ||= self.call_attempts.between(from, to + 1.day).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('TIMESTAMPDIFF(SECOND ,call_end,wrapup_time)')
      round_for_utilization(@time_in_wrapup)
    end

    def time_onhold(from, to)
      time_logged_in(from, to)
      time_on_call(from, to)
      time_in_wrapup(from, to)
      round_for_utilization(@time_logged_in.to_f - @time_on_call.to_f - @time_in_wrapup.to_f)
    end
  end

  module Billing
    def caller_time(from,to)
      self.caller_sessions.between(from, to + 1.day).sum('ceil(TIMESTAMPDIFF(SECOND ,starttime,endtime)/60)').to_i
    end

    def lead_time(from, to)
      self.call_attempts.between(from, to + 1.day).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)').to_i
    end

  end
end

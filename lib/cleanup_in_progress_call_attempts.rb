class CleanupInProgressCallAttempts
  
  class << self
    
    STATUS_CHECK_SQL = "call_attempts.status in ('Ringing', 'Call in progress', 'Call ready to dial')"
    
    MAPING = {
      'not called'     => "call_start IS null",
      'No answer'      => "call_start IS NOT NULL AND call_end IS NULL and connecttime IS NULL",
      'Call abandoned' => "call_start IS NOT NULL AND call_end IS NULL AND connecttime IS NOT NULL",
      'Call failed'    => "call_start IS NOT NULL AND call_end IS NOT NULL"
    }

    JOINS_SQL = " LEFT JOIN voters ON voters.id = call_attempts.voter_id AND voters.last_call_attempt_id = call_attempts.id "
    
    CAMPAIGN_CHECK_SQL = "call_attempts.status = 'not called'"
    
    def update_status_sql(status)
      "call_attempts.status = '#{status}', voters.status = '#{status}'"
    end
    
    def cleanup!
      MAPING.each do |status, condition|
        CallAttempt.joins(JOINS_SQL).where(STATUS_CHECK_SQL).update_all(update_status_sql(status), condition)
      end
    end
    
    def cleanup_for_campaigns!(campaign_ids)
      MAPING.slice('No answer', 'Call abandoned', 'Call failed').each do |status, condition|
        CallAttempt.using(:read_slave1).where(CAMPAIGN_CHECK_SQL).where("call_attempts.campaign_id" => campaign_ids)
          .where(condition).where("call_attempts.created_at < ?", 1.day.ago).pluck("call_attempts.id").each_slice(100) do |ids|
            
            CallAttempt.joins(JOINS_SQL).where("call_attempts.id" => ids).update_all(update_status_sql(status))
          print('.')
        end
      end
    end
  end
end


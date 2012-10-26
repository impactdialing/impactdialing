class AdminReportJob
  @queue = :report_download

  class << self
    def perform(from, to)
      @from_date = Time.parse(from).in_time_zone('Pacific Time (US & Canada)')
      @to_date = Time.parse(to).in_time_zone('Pacific Time (US & Canada)')
      columns = ['account_id', 'email', 'totals']
      output = [] 
      Octopus.using(:read_slave2) do
        account_ids = Account.joins(:campaigns).
          where(["campaigns.created_at > ? AND campaigns.created_at < ?", @from_date, @to_date + 1.day]).pluck("accounts.id").uniq
        account_ids.each do |account_id|
          campaigns = Campaign.where(account_id: account_id).pluck(:id)
          if campaigns.any?
            sessions = CallerSession.where(campaign_id: campaigns).
              where(["created_at > ? AND created_at < ?", @from_date, @to_date + 1.day]).
              where("tCaller IS NOT NULL").sum("ceil(tDuration/60)").to_i
            calls = CallAttempt.from('call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)').
              where(campaign_id: campaigns).
              where(["created_at > ? AND created_at < ?", @from_date, @to_date + 1.day]).
              sum("ceil(tDuration/60)").to_i
            transfers = TransferAttempt.where(campaign_id: campaigns).
              where(["created_at > ? AND created_at < ?", @from_date, @to_date + 1.day]).
              sum("ceil(tDuration/60)").to_i
            output << [account_id, User.where(account_id: account_id).select(:email).first.try(:email), calls+sessions+transfers].join(", ")
          end
        end
      end
      UserMailer.new.deliver_admin_report(from, to,columns.join(', ') +"<br/>"+ output.join('<br/>'))
    end
  end

end

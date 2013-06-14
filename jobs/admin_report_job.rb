class AdminReportJob
  @queue = :upload_download

  class << self
    def prepare_date(date)
      date.utc.strftime("%Y-%m-%d %H:%M:%S")
    end

    def perform(from, to)
      Time.zone = "Pacific Time (US & Canada)"
      @from_date = Time.zone.parse(from).utc
      @to_date = Time.zone.parse(to).utc
      columns = ['account_id', 'email', 'totals']
      output = []
      Octopus.using(:simulator_slave) do
        account_ids = CallerSession.joins(:campaign).
          where(["caller_sessions.created_at > ? AND caller_sessions.created_at < ?", prepare_date(@from_date), prepare_date(@to_date + 1.day)]).
          pluck("campaigns.account_id").uniq
        account_ids.each do |account_id|
          account = Account.find(account_id)
          if account.manual_subscription?
            campaigns = Campaign.where(account_id: account_id).pluck(:id)
            if campaigns.any?
              sessions = CallerSession.where(campaign_id: campaigns).
                where(["created_at > ? AND created_at < ?", prepare_date(@from_date), prepare_date(@to_date + 1.day)]).
                where("tCaller IS NOT NULL").sum("ceil(tDuration/60)").to_i
              calls = CallAttempt.from('call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)').
                where(campaign_id: campaigns).
                where(["created_at > ? AND created_at < ?", prepare_date(@from_date), prepare_date(@to_date + 1.day)]).
                sum("ceil(tDuration/60)").to_i
              transfers = TransferAttempt.where(campaign_id: campaigns).
                where(["created_at > ? AND created_at < ?", prepare_date(@from_date), prepare_date(@to_date + 1.day)]).
                sum("ceil(tDuration/60)").to_i
              output << [account_id, User.where(account_id: account_id).select(:email).first.try(:email), calls+sessions+transfers].join("  ")
            end
          end
        end
      end
      if ["aws", "heroku"].include?(ENV['RAILS_ENV'])
        UserMailer.new.deliver_admin_report(from, to,columns.join("  ") +"<br/>"+ output.join('<br/>'))
      end
    end
  end

end

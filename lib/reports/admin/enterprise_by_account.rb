module Reports::Admin
  class EnterpriseByAccount
    attr_reader :billable_minutes

  public
    def initialize(billable_minutes)
      @billable_minutes = billable_minutes
      @columns = ['Account ID', 'Totals', "\tEmail"]
    end

    def build
      output = []
      account_ids.each do |account_id|
        account = Account.find(account_id)

        if account.manual_subscription?
          account_campaign_ids = campaign_ids(account_id)

          if account_campaign_ids.any?
            total = @billable_minutes.total_for(account_campaign_ids)

            output << [account_id, total, account_email(account_id)].join("\t\t")
          end
        end
      end
      return "#{@columns.join("\t")}\n#{output.join("\n")}"
    end

  private
    def account_ids
      @account_ids ||= CallerSession.joins(:campaign).
        where([
          "caller_sessions.created_at > ? AND caller_sessions.created_at < ?",
          billable_minutes.from_date,
          billable_minutes.to_date
        ]).
        order('campaigns.account_id').
        pluck("campaigns.account_id").uniq
    end

    def campaign_ids(account_id)
      Campaign.where(account_id: account_id).pluck(:id)
    end

    def account_email(account_id)
      User.where(account_id: account_id).select(:email).first.try(:email)
    end
  end
end

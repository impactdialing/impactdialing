module Reports::Admin
  class AllByAccount
    attr_reader :billable_minutes

  public
    def initialize(billable_minutes)
      @billable_minutes = billable_minutes
      @columns = ['Account ID', 'Account Type', 'Total Minutes', 'Undebited Minutes', "\tEmail"]
    end

    def build
      accounts = []
      billable_totals = {}
      undebited_totals = {}
      grand_total = 0

      p "Found #{account_ids.size} accounts"
      account_ids.each do |account_id|
        account = Account.using(:simulator_slave).find(account_id)

        account_campaign_ids = campaign_ids(account_id)
        p "Found #{account_campaign_ids.size} campaigns"
        if account_campaign_ids.any?
          total                        = @billable_minutes.total_for(account_campaign_ids)
          undebited                    = @billable_minutes.total_undebited_for(account_campaign_ids)
          billable_totals[account_id]  = total
          undebited_totals[account_id] = undebited
          grand_total                 += total

          accounts << account
        end
      end
      from, to = billable_minutes.from_date, billable_minutes.to_date
      return AccountUsageRender.new.by_account(:text, from, to, billable_totals, undebited_totals, grand_total, accounts)
    end

  private
    def account_ids
      @account_ids ||= CallerSession.using(:simulator_slave).joins(:campaign).
        where([
          "caller_sessions.created_at > ? AND caller_sessions.created_at < ?",
          billable_minutes.from_date,
          billable_minutes.to_date
        ]).
        order('campaigns.account_id').
        pluck("campaigns.account_id").uniq
    end

    def campaign_ids(account_id)
      Campaign.using(:simulator_slave).where(account_id: account_id).pluck(:id)
    end

    def account_email(account_id)
      User.using(:simulator_slave).where(account_id: account_id).select(:email).first.try(:email)
    end
  end
end

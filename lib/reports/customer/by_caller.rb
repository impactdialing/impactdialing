module Reports::Customer
  class ByCaller
      attr_reader :billable_minutes
    public
      def initialize(billable_minutes, account)
        @billable_minutes = billable_minutes
        @account = account
      end

      def build
        groups = billable_minutes.groups(caller_ids, 'callers')
        billable_minutes.calculate_group_total(groups)
      end

    private
      def caller_ids
        Caller.using(:simulator_slave).where(account_id: @account.id).pluck(:id)
      end
      def campaign_ids
        Caller.using(:simulator_slave).where(account_id: @account.id).pluck(:campaign_id)
      end
  end
end

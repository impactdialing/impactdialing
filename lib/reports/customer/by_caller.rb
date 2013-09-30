module Reports::Customer
  class ByCaller
      attr_reader :billable_minutes
    public
      def initialize(billable_minutes, account)
        @billable_minutes = billable_minutes
        @account = account
      end

      def build
        # groups = billable_minutes.groups(caller_ids, 'callers')
        # billable_minutes.calculate_group_total(groups)

        grouped = billable_minutes.relations('callers').map do |relation|
          relation = billable_minutes.with_campaigns(relation, campaign_ids)
          relation = billable_minutes.from_to(relation)
          relation = relation.group('caller_id')
          billable_minutes.sum(relation)
        end

        billable_minutes.calculate_group_total(grouped)
      end

    private
      def caller_ids
        Caller.where(account_id: @account.id).pluck(:id)
      end
      def campaign_ids
        Caller.where(account_id: @account.id).pluck(:campaign_id)
      end
      # TODO: implement below reports
      # def usage
      #   authorize! :view_campaign_reports, @account
      #   load_campaign
      #   set_dates
      #   @campaign_usage = CampaignUsage.new(@campaign, @from_date, @to_date)
      # end

      # def dials
      #   authorize! :view_campaign_reports, @account
      #   load_campaign
      #   set_dates
      #   @show_summary = true if params[:from_date].blank? || params[:to_date].blank?
      #   @dials_report = DialReport.new
      #   @dials_report.compute_campaign_report(@campaign, @from_date, @to_date)
      # end
  end
end

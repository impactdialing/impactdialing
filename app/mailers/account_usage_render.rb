class AccountUsageRender < AbstractController::Base
  include AbstractController::Rendering
  include AbstractController::Layouts
  include AbstractController::Helpers
  include AbstractController::Translation
  include AbstractController::AssetPaths

  self.view_paths = "app/views"
  layout "email"

private
  def tt_longest(headers, values)
    longest = []
    headers.size.times{ longest << 0 }
    values.map! do |n|
      n.sort_by do |x|
        x.blank? ? 0 : x.size
      end.last
    end

    [headers,values].each do |items|
      items.each_with_index do |str,i|
        next if str.blank?
        l = longest[i]
        l = str.size > l ? str.size : l
        longest[i] = l
      end
    end
    # padding
    @longest = longest.map{|l| l += 5}
  end

public

  def by_campaigns(content_type, from_date, to_date, billable_totals, grand_total, campaigns)
    @from_date       = from_date
    @to_date         = to_date
    @billable_totals = billable_totals
    @grand_total     = grand_total
    @campaigns       = campaigns
    opts             = {
      template: "account_usage_mailer/by_campaigns.#{content_type}",
      format: content_type
    }
    render(opts)
  end

  def by_callers(content_type, from_date, to_date, billable_totals, status_totals, grand_total, callers)
    @from_date       = from_date
    @to_date         = to_date
    @billable_totals = billable_totals
    @status_totals   = status_totals
    @grand_total     = grand_total
    @callers         = callers
    opts             = {
      template: "account_usage_mailer/by_callers.#{content_type}",
      format: content_type
    }
    render(opts)
  end

  def by_account(content_type, from_date, to_date, billable_totals, undebited_totals, grand_total, accounts)
    @from_date         = from_date
    @to_date           = to_date
    @billable_totals   = billable_totals
    @undebited_totals  = undebited_totals
    @include_undebited = !@undebited_totals.empty?
    @grand_total       = grand_total
    @accounts          = accounts

    headers = ['Account ID', 'Account Type', 'Billable Minutes']
    values  = [accounts.map(&:id).map(&:to_s), accounts.map(&:billing_subscription).map(&:plan).map(&:humanize) + ['No current subscription'], billable_totals.values.map(&:to_s)]
    if @include_undebited
      headers << 'Undebited Minutes'
      values << undebited_totals.values.map(&:to_s)
    end
    @longest           = tt_longest(headers, values)
    opts               = {
      template: "account_usage_mailer/by_account.#{content_type}",
      formate:  content_type
    }
    render(opts)
  end
end

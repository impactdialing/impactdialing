##
# Provides methods for building queries and aggregating
# billable minutes usage.
#
# This class should not be used to build reports directly.
# Instead an instance of the class should be passed to
# a builder object that generates the needed report.
#
# Usage:
#     class MyReport
#       attr_reader :billable_minutes
#       def initialize(billable_minutes)
#         @billable_minutes = billable_minutes
#       end
#
#       def build
#         ...generate report...
#       end
#     end
#
#     billable_minutes = Reports::BillableMinutes.new(from_date_obj, to_date_obj)
#     report = MyReport.new(billable_minutes)
#     print report.build
#
class Reports::BillableMinutes
  attr_reader :from_date, :to_date

public
  def initialize(from, to)
    @from_date = from
    @to_date = to
  end

  def total_for(ids, with='campaigns')
    method = "with_#{with}"
    group_by = with == 'campaigns' ? 'campaign_id' : 'caller_id'

    counts = relations(with).map do |relation|
      sum( from_to( send(method, relation, ids) ) )
    end
    return calculate_total(counts)
  end

  def group_total_for(ids, with='campaigns')
    grouped = groups(ids, with)
    return calculate_group_total(grouped)
  end

  def calculate_total(counts)
    return counts.inject(0){ |s,n| s + n.to_i }
  end

  def calculate_group_total(grouped)
    totals = {}
    grouped.each do |group|
      group.each do |id,count|
        totals[id] ||= 0
        totals[id] += (count || 0).to_i
      end
    end
    totals
  end

  def relation(type)
    types = [:caller_sessions, :call_attempts, :transfer_attempts]
    i = types.index type
    relations[i]
  end

  def sum(relation)
    out = relation.sum("ceil(#{relation.table_name}.tDuration/60)")
    if out.respond_to? :to_i
      return out.to_i
    end
    return out
  end

  def relations(with='campaigns')
    [caller_sessions, call_attempts, transfer_attempts(with)]
  end

  def groups(ids, with)
    method = "with_#{with}"
    group_by = with == 'campaigns' ? 'campaign_id' : 'caller_id'

    relations(with).map do |relation|
      with_dates = from_to( send(method, relation, ids) )
      sum( group(with_dates, group_by) )
    end
  end

  def from_to(relation)
    relation.where(["#{relation.table_name}.created_at > ? AND #{relation.table_name}.created_at < ?", @from_date, @to_date])
  end

  def group(relation, group_by)
    relation.group(group_by)
  end

  def with_campaigns(relation, campaign_ids)
    relation.where(campaign_id: campaign_ids)
  end

  def with_callers(relation, caller_ids)
    if relation.table_name == transfer_attempts('callers').table_name
      return relation.where(["caller_sessions.caller_id in (?)", caller_ids])
    else
      return relation.where(caller_id: caller_ids)
    end
  end

  def without_callers(relation)
    relation.where("#{relation.table_name}.caller_id IS NULL")
  end

  def caller_sessions
    # We only charge for phone minutes used. Callers can call in from either
    # a compatible browser or their phone. If they call in via a browser then
    # we do not charge them for minutes they are simply connected to the system.
    # If they call in via a phone then we do charge them for minutes they are
    # simply connected to the system.
    CallerSession.using(:simulator_slave).
      where(caller_type: CallerSession::CallerType::PHONE)
  end

  def call_attempts
    # We charge for all outgoing calls (all call attempts).
    CallAttempt.using(:simulator_slave).
      from('call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)')
  end

  def transfer_attempts(with='campaigns')
    # We charge for all outgoing calls (all transfer attempts).
    ta = TransferAttempt.using(:simulator_slave)
    if with == 'callers'
      ta = TransferAttempt.
            joins(:caller_session).
            select('transfer_attempts.*, caller_sessions.caller_id as caller_id')
    end
    return ta
  end
end
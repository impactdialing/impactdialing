require 'uuid'

class MigrateRedis
  attr_reader :campaign, :household, :uuid

  def self.go
    Campaign.active.find_in_batches(batch_size: 10) do |campaigns|
      campaigns.each do |campaign|
        migration_instance = self.new(campaign)
        campaign.households.includes({
          :voters => :voter_list
        }).find_in_batches(batch_size: 500) do |households|
          households.each do |household|
            migration_instance.do(household)
          end
        end
      end
    end
  end

  def redis_keys(record)
    {
      available: {
        active: "dial_queue:#{record.id}:active",
        presented: "dial_queue:#{record.id}:presented"
      },
      recycle_bin: "dial_queue:#{record.id}:bin",
      blocked: "dial_queue:#{record.id}:blocked",
      completed: "dial_queue:#{record.id}:completed",
      failed: "dial_queue:#{record.id}:failed",
      households: {
        active: "dial_queue:#{record.id}:households:active",
        presented: "dial_queue:#{record.id}:households:presented",
        inactive: "dial_queue:#{record.id}:households:inactive",
        message_drops: "dial_queue:#{record.id}:households:message_drops",
        completed_leads: "dial_queue:#{record.id}:households:completed_leads",
        dispositioned_leads: "dial_queue:#{record.id}:households:dispositioned_leads"
      },
      stats: {
        voter_list: "list:voter_list:#{record.id}:stats",
        campaign: "list:campaign:#{record.id}:stats"
      },
      id_register: {
        base: "list:#{record.id}:custom_ids"
      }
    }
  end

  def stats_hash_keys
    {
      lead: {
        sequence: 'lead_sequence'
      },
      number: {
        sequence: 'number_sequence'
      },
      list: {
        total_numbers: 'total_numbers',
        total_leads: 'total_leads'
      },
      campaign: {
        total_numbers: 'total_numbers',
        total_leads: 'total_leads'
      }
    }
  end

  def initialize(campaign)
    @campaign = campaign
    @uuid     = UUID.new
  end

  def use_custom_ids?
    @use_custom_ids ||= campaign.voter_lists.first.csv_to_system_map.values.include? 'custom_id'
  end

  def run(household, &block)
    base_key        = redis_keys(campaign)[:households][:active]
    house_redis_key = "#{base_key}:#{household.phone[0..-4]}"
    house_hash_key  = household.phone[-3..-1]
    house = {
      message_dropped: household.voicemail_delivered? ? 1 : 0,
      dialed: household.call_attempts.count.zero? ? 0 : 1,
      completed: household.complete? ? 1 : 0,
      failed: household.failed? ? 1 : 0,
      blocked: household.blocked_before_type_cast,
      phone: household.phone,
      uuid: uuid.generate,
      campaign_id: household.campaign_id,
      account_id: household.account_id,
      sql_id: household.id,
      score: household.presented_at.to_f
    }

    lead_id_map = {}

    household.voters.each do |voter|
      lead_id_map[voter.id]                 = {}
      lead_id_map[voter.id][:uuid]          = uuid.generate
      lead_id_map[voter.id][:voter_list_id] = voter.voter_list_id
      lead_id_map[voter.id][:dispositioned] = voter.answers.count > 0 ? 1 : 0
      lead_id_map[voter.id][:completed]     = voter.answers.any?{|a| a.possible_response.retry?} ? 0 : 1
    end

    yield house, lead_id_map, house_redis_key, house_hash_key
  end

  def import(household)
    run(household) do |house, lead_id_map, house_redis_key, house_hash_key|
      inactive_base = redis_keys(campaign)[:households][:inactive]
      inactive_redis_key = "#{inactive_base}:#{household.phone[0..-4]}"
      house[:leads] = []
      whitelist = %w(custom_id first_name last_name 
                    middle_name suffix email campaign_id
                    account_id address city state zip_code country)
      household.voters.each do |voter|
        id_map = lead_id_map[voter.id]
        lead = {
          uuid: id_map[:uuid],
          voter_list_id: id_map[:voter_list_id],
          sql_id: voter.id,
          phone: household.phone
        }
        Voter.column_names.each do |c|
          lead[c] = voter[c] if whitelist.include?(c)
        end
        lead['enabled'] = voter.enabled_before_type_cast
        voter.custom_voter_field_values.includes(:custom_voter_field).each do |field_value|
          lead[field_value.custom_voter_field.name] = field_value.value
        end
        house[:leads] << lead
      end

      Wolverine.migrate.household({
        keys: [],
        argv: [
          house.to_json,
          nil, # enabled bit (set above)
          lead_id_map.to_json,
          house_redis_key,
          house_hash_key,
          redis_keys(campaign)[:stats][:campaign],
          redis_keys(campaign)[:households][:dispositioned_leads],
          redis_keys(campaign)[:households][:completed_leads],
          redis_keys(campaign)[:households][:message_drops],
          redis_keys(campaign)[:id_register][:base],
          redis_keys(campaign)[:available][:active],
          redis_keys(campaign)[:blocked],
          redis_keys(campaign)[:completed],
          redis_keys(campaign)[:failed],
          inactive_redis_key,
          redis_keys(campaign)[:stats][:voter_list]
        ]
      })
    end
  end
end


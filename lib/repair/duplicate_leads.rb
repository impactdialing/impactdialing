module Repair
  class EmptyHouseholds
    attr_reader :dial_queue, :phone

    delegate :households, to: :dial_queue

    def initialize(dial_queue, phone)
      @dial_queue = dial_queue
      @phone      = phone
    end

    def household
      @household ||= households.find(phone)
    end

    def leads_empty?
      empty? or household[:leads].empty?
    end

    def empty?
      household.empty? or household[:leads].nil?
    end

    def fixit
      if household_empty?
        # remove number from zsets
        # if household_record has any voters
        #   and all voters are complete
        #     add number to completed zset
        # if household_record status is failed
        #   add number to failed zset
      end
    end
  end

  class DuplicateLeads
    attr_reader :dial_queue, :duplicates_detected, :phone
    attr_accessor :household, :leads, :grouped_leads, :survivors, :counts

    delegate :households, to: :dial_queue
    delegate :available, to: :dial_queue
    delegate :recycle_bin, to: :dial_queue
    delegate :completed, to: :dial_queue
    delegate :campaign, to: :dial_queue

private
  def filter(persisted_leads, meth)
    persisted_leads.select{|lead| households.send(meth, lead['sequence'])}
  end

  def count_removed_by_list_id(leads, survivor)
    leads.each do |lead|
      self.counts[:removed_by_list][lead['voter_list_id']] ||= 0
      self.counts[:removed_by_list][lead['voter_list_id']] += 1
    end
    if self.counts[:removed_by_list][survivor['voter_list_id']] > 0
      # don't count the survivor as removed
      self.counts[:removed_by_list][survivor['voter_list_id']] -= 1
    end
  end

  def zscore(key)
    redis.zscore key, phone
  end

  def zadd(key, scored_phone)
    redis.zadd key, scored_phone
  end

  def redis
    @redis ||= households.redis
  end

public
    def initialize(dial_queue, phone, detect_duplicates_on=:uuid)
      @dial_queue          = dial_queue
      @phone               = phone
      @duplicates_detected = false

      self.household       = households.find(phone)
      self.leads           = household[:leads] || []
      self.grouped_leads   = households.find_grouped_leads(phone, detect_duplicates_on)
      self.survivors       = []
      self.counts          = {
        removed_by_list: {}
      }
    end

    def household_record
      @household_record || campaign.households.where(phone: phone).first
    end

    def any_duplicate_leads?
      @duplicates_detected ||= grouped_leads.values.any?{|leads| leads.size > 1}
    end

    def no_duplicate_leads?
      not any_duplicate_leads?
    end

    def dedup_redis
      return if no_duplicate_leads?

      grouped_leads.each do |uuid, leads|
        persisted_leads       = leads.select{|lead| lead[:sql_id]}
        dispositioned_leads   = filter(persisted_leads, :lead_dispositioned?)
        completed_leads       = filter(persisted_leads, :lead_completed?)

        if leads.size.zero?
          puts "No leads returned for Phone[#{phone}] UUID[#{uuid}] Campaign[#{campaign.id}]"
          next
        end

        survivor = (completed_leads.first     ||
                    dispositioned_leads.first ||
                    persisted_leads.first     ||
                    leads.first)
        count_removed_by_list_id(leads, survivor)

        self.survivors << survivor
      end

      self.household[:leads] = survivors
      households.save(phone, household)
    end

    def update_dial_queue
      return if no_duplicate_leads? or households.dial_again?(phone)

      score = zscore(recycle_bin.keys[:bin])
      if score
        recycle_bin.remove(phone)
      else
        score = zscore(available.keys[:active])
        if score
          available.remove(phone)
        end
      end

      if score
        zadd(completed.keys[:completed], [score, phone])
      else
        puts "Could not find Phone[#{phone}] in available or recycle bin"
      end
    end

    def dedup_sql
      return if no_duplicate_leads?

      sql_ids = survivors.map{|lead| lead[:sql_id]}.compact.uniq
      if household_record and sql_ids.any?
        household_record.voters.where('id NOT IN (?)', sql_ids).destroy_all
      end
    end

    def fixit
      dedup_redis
      dedup_sql
      update_dial_queue
    end
  end
end


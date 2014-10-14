##
#
class CallFlow::DialQueue::DoNotCall
  attr_reader :campaign

  delegate :recycle_rate, to: :campaign

  include CallFlow::DialQueue::Util

private
  def _benchmark
    @_benchmark ||= ImpactPlatform::Metrics::Benchmark.new("dial_queue.#{campaign.account_id}.#{campaign.id}.available")
  end

  def keys
    {
      account_dnc: "dnc:#{campaign.account_id}",
      campaign_dnc: "dnc:#{campaign.account_id}:#{campaign.id}",
      last_loaded_account_id: "dnc:#{campaign.account_id}:last_id",
      last_loaded_campaign_id: "dnc:#{campaign.account_id}:#{campaign.id}:last_id"
    }
  end

  def last_loaded_account_id
    redis.get(keys[:last_loaded_account_id]).to_i
  end

  def last_loaded_campaign_id
    redis.get(keys[:last_loaded_campaign_id]).to_i
  end

  def last_loaded_account_id=(id)
    redis.set keys[:last_loaded_account_id], id
  end

  def last_loaded_campaign_id=(id)
    redis.set keys[:last_loaded_campaign_id], id
  end

  def cache_account_dnc!
    account_wide = campaign.account.blocked_numbers.account_wide.
                    where('id > ?', last_loaded_account_id)
    cache_dnc!(account_wide, 'account')
  end

  def cache_campaign_dnc!
    campaign_wide = campaign.account.blocked_numbers.with_campaign(campaign).
                     where('id > ?', last_loaded_campaign_id)
    cache_dnc!(campaign_wide, 'campaign')
  end

  def cache_dnc!(dnc, dnc_type)
    return if dnc.count.zero?

    self.send("last_loaded_#{dnc_type}_id=", dnc.last.id)
    redis.sadd keys["#{dnc_type}_dnc".to_sym], dnc.pluck(:number)
  end

public
  def initialize(campaign)
    @campaign = campaign
  end

  def cache!
    cache_account_dnc!
    cache_campaign_dnc!
  end

  def campaign_dnc
    redis.smembers keys[:campaign_dnc]
  end

  def account_dnc
    redis.smembers keys[:account_dnc]
  end

  def all
    redis.sunion keys[:campaign_dnc], keys[:account_dnc]
  end

  def size
    redis.scard(keys[:campaign_dnc]) + redis.scard(keys[:account_dnc])
  end

  def peak(list=campaign_dnc)
    redis.srange keys[list], 0, -1
  end
end

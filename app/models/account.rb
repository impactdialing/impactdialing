# todo: remove credit_card_declined attribute
class Account < ActiveRecord::Base
  TRIAL_MINUTES_ALLOWED   = 50
  TRIAL_NUMBER_OF_CALLERS = 5

  include SubscriptionInfo

  has_many :users
  has_many :campaigns, :conditions => {:active => true}
  has_many :all_campaigns, :class_name => 'Campaign'
  has_many :recordings
  has_many :custom_voter_fields

  # todo: remove has_many :subscriptions cruft
  has_many :subscriptions
  has_one :billing_subscription, class_name: 'Billing::Subscription'
  has_one :quota

  has_many :scripts
  has_many :callers
  has_many :voter_lists
  has_many :voters
  has_many :blocked_numbers
  has_many :moderators
  has_many :questions, :through => :scripts
  has_many :script_texts, :through => :scripts
  has_many :notes, :through => :scripts
  has_many :possible_responses, :through => :scripts, :source => :questions
  has_many :caller_groups

  attr_accessible :api_key, :domain_name, :abandonment, :card_verified, :activated, :record_calls, :recurly_account_code, :subscription_name, :subscription_count, :subscription_active, :recurly_subscription_uuid, :autorecharge_enabled, :autorecharge_amount, :autorecharge_trigger, :status, :tos_accepted_date

  before_create :assign_api_key
  after_create :setup_trial!
  validate :check_subscription_type_for_call_recording, on: :update

  delegate :minutes_available?, to: :quota

private
  def ability
    Ability.new(self)
  end

  def setup_trial!
    create_quota!({
      minutes_allowed: TRIAL_MINUTES_ALLOWED,
      callers_allowed: TRIAL_NUMBER_OF_CALLERS
    })
    create_billing_subscription!({
      plan: 'Trial'
    })
  end

public
  def check_subscription_type_for_call_recording
    if record_calls && ability.cannot?(:record_calls, self)
      errors.add(:base, 'Your subscription does not allow call recordings.')
    end
  end

  def upgraded_to_enterprise
    update_attributes({
      activated: true,
      card_verified: true,
      subscription_name: "Manual"
    })
  end

  # todo: remove #zero_all_subscription_minutes
  def zero_all_subscription_minutes!
    Rails.logger.debug('Deprecated!')
    if available_minutes > 0
      current_subscriptions.each do |s|
        return s unless s.zero_minutes!
      end
    end
    return true
  end

  def administrators
    users.select{|x| x.administrator? }
  end

  def update_caller_password(password)
    hash_caller_password(password)
    self.save
  end

  def hash_caller_password(password)
    self.caller_hashed_password_salt = SecureRandom.base64(8)
    self.caller_password = Digest::SHA2.hexdigest(caller_hashed_password_salt + password)
  end

  def self.authenticate_caller?(pin, password)
    caller = Caller.find_by_pin(pin)
    return nil if caller.nil?
    account = caller.account
    if password.nil? || account.caller_password.nil? || account.caller_hashed_password_salt.nil?
      return nil
    end
    if account.caller_password == Digest::SHA2.hexdigest(account.caller_hashed_password_salt + password)
      caller
    else
      nil
    end
  end

  def callers_in_progress
    caller_seats_taken
  end

  def _campaign_ids
    @_campaign_ids ||= Campaign.where(account_id: id).pluck('id').uniq
  end
  def caller_seats_taken
    return CallerSession.on_call_in_campaigns(_campaign_ids).count
  end

  def funds_available?
    minutes_available?
  end

  def enable_api!
    self.update_attribute(:api_key, generate_api_key)
  end

  def disable_api!
    self.update_attribute(:api_key, "")
  end

  def api_is_enabled?
    !api_key.empty?
  end

  def paid?
    Rails.logger.debug('Deprecated! Call #activated? instead.')
    Rails.logger.debug("Called from #{caller[1]}")
    activated?
  end


  def toggle_call_recording!
    self.record_calls = !self.record_calls
    self.save
  end

  def terms_and_services_accepted?
    !self.tos_accepted_date.nil?
  end

  def account_after_change_in_tos?
    self.created_at >= Date.parse('24th June 2013')
  end

  def custom_fields
    custom_voter_fields
  end

  def variable_abandonment?
    abandonment == 'variable'
  end

  def abandonment_value
    if variable_abandonment?
      "Variable"
    else
      "Fixed"
    end
  end

  def secure_digest(*args)
    Digest::SHA1.hexdigest(args.flatten.join('--'))
  end

  def assign_api_key
    self.api_key = generate_api_key
  end

  def generate_api_key
    secure_digest(Time.now, (1..10).map{ rand.to_s })
  end
end

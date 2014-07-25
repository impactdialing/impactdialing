require Rails.root.join("lib/twilio_lib")
class TransferAttempt < ActiveRecord::Base
  belongs_to :transfer
  belongs_to :caller_session
  belongs_to :call_attempt
  belongs_to :campaign
  include Rails.application.routes.url_helpers
  scope :within, lambda { |from, to, campaign_id| where(:created_at => from..to).where(campaign_id: campaign_id)}
  scope :between, lambda { |from_date, to_date| {:conditions => {:created_at => from_date..to_date}} }

  scope :undebited, where(debited: false)
  scope :successful_call, where("status NOT IN ('No answer', 'No answer busy signal', 'Call failed')")
  scope(:with_time_and_duration,
        where('tStartTime IS NOT NULL').
        where('tEndTime IS NOT NULL').
        where('tDuration IS NOT NULL')
  )
  scope :debit_pending, undebited.successful_call.with_time_and_duration

  def conference
    Twilio::TwiML::Response.new do |r|
      r.Dial :hangupOnStar => 'false', :action => disconnect_transfer_path(self, :host => Settings.twilio_callback_host, :protocol => "http://"), :record=>caller_session.campaign.account.record_calls do |d|
        d.Conference session_key, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET', :beep => false, :endConferenceOnExit => false
      end
    end.text
  end

  def warm_transfer?
    transfer_type == Transfer::Type::WARM
  end

  def fail
     xml =  Twilio::Verb.new do |v|
       v.say "The transfered call was not answered "
       v.hangup
    end
    xml.response
  end

  def hangup
    Twilio::TwiML::Response.new { |r| r.Hangup }.text
  end

  def self.aggregate(attempts)
    result = Hash.new
    attempts.each do |attempt|
      unless attempt.transfer.nil?
        if result[attempt.transfer.id].nil?
          result[attempt.transfer.id] = {label: attempt.transfer.label, number: 0}
        end
        result[attempt.transfer.id][:number] = result[attempt.transfer.id][:number]+1
      end

    end

    total = 0

    result.each_value do |value|
      total = total + value[:number]
    end

    result.each_pair do |key, value|
      value[:percentage] = (value[:number] *100) / total
    end

    result
  end


end

# ## Schema Information
#
# Table name: `transfer_attempts`
#
# ### Columns
#
# Name                     | Type               | Attributes
# ------------------------ | ------------------ | ---------------------------
# **`id`**                 | `integer`          | `not null, primary key`
# **`transfer_id`**        | `integer`          |
# **`caller_session_id`**  | `integer`          |
# **`call_attempt_id`**    | `integer`          |
# **`script_id`**          | `integer`          |
# **`campaign_id`**        | `integer`          |
# **`call_start`**         | `datetime`         |
# **`call_end`**           | `datetime`         |
# **`status`**             | `string(255)`      |
# **`connecttime`**        | `datetime`         |
# **`sid`**                | `string(255)`      |
# **`session_key`**        | `string(255)`      |
# **`created_at`**         | `datetime`         |
# **`updated_at`**         | `datetime`         |
# **`transfer_type`**      | `string(255)`      |
# **`tPrice`**             | `float`            |
# **`tStatus`**            | `string(255)`      |
# **`tCallSegmentSid`**    | `string(255)`      |
# **`tAccountSid`**        | `string(255)`      |
# **`tCalled`**            | `string(255)`      |
# **`tCaller`**            | `string(255)`      |
# **`tPhoneNumberSid`**    | `string(255)`      |
# **`tStartTime`**         | `datetime`         |
# **`tEndTime`**           | `datetime`         |
# **`tDuration`**          | `integer`          |
# **`tFlags`**             | `integer`          |
# **`debited`**            | `boolean`          | `default(FALSE)`
#
# ### Indexes
#
# * `index_transfer_attempts_debit`:
#     * **`debited`**
#     * **`status`**
#     * **`tStartTime`**
#     * **`tEndTime`**
#     * **`tDuration`**
#

class Moderator < ActiveRecord::Base
  belongs_to :caller_session
  belongs_to :account
  scope :active, :conditions => {:active => true}

  def switch_monitor_mode(type)
    caller_session = CallerSession.find(caller_session_id)
    conference_sid = get_conference_id(caller_session)
    self.update_attributes(caller_session_id: caller_session_id)
    if type == "breakin"
      Twilio::Conference.unmute_participant(conference_sid, call_sid)
    else
      Twilio::Conference.mute_participant(conference_sid, call_sid)
    end
  end

  def update_caller_session(caller_session_id)
    update_attributes({
      caller_session_id: caller_session_id
    })
  end

  def stop_monitoring(caller_session)
    conference_sid = get_conference_id(caller_session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Conference.kick_participant(conference_sid, call_sid)
  end

  def self.active_moderators(campaign)
    campaign.account.moderators.last_hour.active.select('session')
  end

  def get_conference_id(caller_session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    conferences = Twilio::Conference.list({"FriendlyName" => caller_session.session_key})
    confs = conferences.parsed_response['TwilioResponse']['Conferences']['Conference']
    confs.class == Array ? confs.last['Sid'] : confs['Sid']
  end

end

# ## Schema Information
#
# Table name: `moderators`
#
# ### Columns
#
# Name                     | Type               | Attributes
# ------------------------ | ------------------ | ---------------------------
# **`id`**                 | `integer`          | `not null, primary key`
# **`caller_session_id`**  | `integer`          |
# **`call_sid`**           | `string(255)`      |
# **`created_at`**         | `datetime`         |
# **`updated_at`**         | `datetime`         |
# **`session`**            | `string(255)`      |
# **`active`**             | `string(255)`      |
# **`account_id`**         | `integer`          |
#
# ### Indexes
#
# * `active_moderators`:
#     * **`session`**
#     * **`active`**
#     * **`account_id`**
#     * **`created_at`**
# * `index_active_moderators`:
#     * **`account_id`**
#     * **`active`**
#     * **`created_at`**
#

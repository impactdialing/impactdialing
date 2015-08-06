require 'impact_platform/metrics'

class Call < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallTwiml

  has_one :call_attempt
  delegate :connect_call, :to => :call_attempt
  delegate :campaign, :to=> :call_attempt
  delegate :voter, :to=> :call_attempt
  delegate :household, :to => :call_attempt
  delegate :caller_session, :to=> :call_attempt
  delegate :end_caller_session, :to=> :call_attempt
  delegate :caller_session_key, :to=> :call_attempt
  delegate :enqueue_call_flow, :to=> :call_attempt
  delegate :update_recording!, :to => :call_attempt

  # class is on the way out: keeping until redis-uploads has been deployed & all data migrated
end

# ## Schema Information
#
# Table name: `calls`
#
# ### Columns
#
# Name                      | Type               | Attributes
# ------------------------- | ------------------ | ---------------------------
# **`id`**                  | `integer`          | `not null, primary key`
# **`call_attempt_id`**     | `integer`          |
# **`state`**               | `string(255)`      |
# **`call_sid`**            | `string(255)`      |
# **`call_status`**         | `string(255)`      |
# **`answered_by`**         | `string(255)`      |
# **`recording_duration`**  | `integer`          |
# **`recording_url`**       | `string(255)`      |
# **`created_at`**          | `datetime`         |
# **`updated_at`**          | `datetime`         |
# **`questions`**           | `text`             |
# **`notes`**               | `text`             |
# **`all_states`**          | `text`             |
#

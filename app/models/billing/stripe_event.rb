class Billing::StripeEvent < ActiveRecord::Base
  attr_accessible :data, :name, :pending_webhooks, :processed, :provider_created_at, :provider_id, :request

  serialize :data, HashWithIndifferentAccess

  validates_uniqueness_of :provider_id
  validates_presence_of :provider_id

  scope :pending, where('processed IS NULL')

  def cache_event!(remote_event)
    self.data                = HashWithIndifferentAccess.new(JSON.parse(remote_event.data.to_json))
    self.name                = remote_event.type
    self.livemode            = remote_event.livemode
    self.provider_created_at = remote_event.created
    self.pending_webhooks    = remote_event.pending_webhooks
    self.request             = remote_event.request
    save!
  end

  def bare?
    data.blank? && name.blank? && provider_created_at.blank?
  end
end

# ## Schema Information
#
# Table name: `billing_stripe_events`
#
# ### Columns
#
# Name                       | Type               | Attributes
# -------------------------- | ------------------ | ---------------------------
# **`id`**                   | `integer`          | `not null, primary key`
# **`provider_id`**          | `string(255)`      | `not null`
# **`provider_created_at`**  | `date`             |
# **`name`**                 | `string(255)`      |
# **`request`**              | `string(255)`      |
# **`pending_webhooks`**     | `integer`          |
# **`data`**                 | `text`             |
# **`processed`**            | `datetime`         |
# **`livemode`**             | `boolean`          |
# **`created_at`**           | `datetime`         | `not null`
# **`updated_at`**           | `datetime`         | `not null`
#
# ### Indexes
#
# * `index_billing_stripe_events_on_provider_id`:
#     * **`provider_id`**
#

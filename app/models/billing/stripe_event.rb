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

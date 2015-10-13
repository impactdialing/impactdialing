RSpec::Matchers.define :invalidate_recycle_rate do |recycle_rate|
  match do |campaign|
    campaign.recycle_rate = recycle_rate
    recycle_rate_error    = "#{I18n.t('activerecord.attributes.campaign.recycle_rate')} must be a number and at least 1"
    campaign.valid?

    campaign.errors.full_messages.include?(recycle_rate_error)
  end
end

RSpec::Matchers.define :validate_recycle_rate do |recycle_rate|
  match do |campaign|
    campaign.recycle_rate = recycle_rate
    campaign.valid?
    campaign.errors[:recycle_rate].empty?
  end
end


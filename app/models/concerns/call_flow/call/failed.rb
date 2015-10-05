class CallFlow::Call::Failed < CallFlow::Call::Lead
  attr_reader :campaign_id, :phone

  def self.namespace
    "failed"
  end

  def self.create(campaign, phone, rest_response, update_presented=false)
    phone = PhoneNumber.sanitize(phone)

    validate!(campaign.try(:id), phone)

    storage = CallFlow::Call::Storage.new(campaign.id, phone, namespace)

    params = rest_response.merge({
      mapped_status: CallAttempt::Status::FAILED,
      phone: phone,
      campaign_id: campaign.id
    })

    campaign.dial_queue.failed!(phone, update_presented)

    storage.save(params)

    CallFlow::Jobs::Persistence.perform_async('Failed', campaign.id, phone)
  end

  def initialize(campaign_id, phone)
    @campaign_id = campaign_id
    @phone       = phone
  end

  def answered_by_human?
    false
  end

  def completed?
    false
  end

  def dispositioned?
    false
  end

  def self.validate!(campaign_id, phone)
    if campaign_id.blank? or phone.blank?
      raise CallFlow::Call::InvalidParams, "Campaign ID and phone are both required for CallFlow::Call::Failed. They were: Campaign ID: #{campaign_id} and Phone: #{phone}"
    end
  end

  def validate!
    self.class.validate!(campaign_id, phone)
  end

  def storage
    @storage ||= CallFlow::Call::Storage.new(campaign_id, phone, namespace)
  end
end


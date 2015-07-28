class CallFlow::Call::Dialed < CallFlow::Call::Lead
private
  def self.storage_key(rest_response)
    CallFlow::Call::Storage.key(rest_response['account_sid'], rest_response['sid'], 'dialed')
  end

  def self.keys(campaign, rest_response)
    [
      Twillio::InflightStats.key(campaign),
      self.storage_key(rest_response)
    ]
  end

  def self.lua_options(campaign, rest_response, optional_properties)
    {
      keys: keys(campaign, rest_response),
      argv: [
        params_for_create(rest_response).to_json,
        optional_properties.to_json,
        campaign.predictive? ? 1 : 0
      ]
    }
  end

public
  def self.create(campaign, rest_response, optional_properties={})
    opts = lua_options(campaign, rest_response, optional_properties)
    Wolverine.call_flow.dialed(opts)
    if campaign.class.to_s !~ /(Preview|Power|Predictive)/ or campaign.new_record?
      raise ArgumentError, "CallFlow::Call::Dialed received new or unknown campaign: #{campaign.class}"
    end

    self.new(rest_response['account_sid'], rest_response['sid'])
  end

  def self.namespace
    'dialed'
  end

  def namespace
    self.class.namespace
  end
end


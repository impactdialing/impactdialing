module CallFlow
  module TwilioCallParams
    def self.constant_twiml_param_keys
      ['CallSid', 'AccountSid', 'From', 'To', 'CallStatus', 'Direction']
    end

    def self.constant_new_call_response_param_keys
      ['sid', 'account_sid', 'from', 'to', 'status', 'direction', 'date_created']
    end

    def self.constant_param_keys
      constant_twiml_param_keys + constant_new_call_response_param_keys
    end

    def self.optional_param_keys
      [
        'FromCity', 'FromState', 'FromZip', 'FromCountry',
        'ToCity', 'ToState', 'ToZip', 'ToCountry'
      ]
    end

    def self.status_param_keys
      ['CallDuration', 'RecordingUrl', 'RecordingSid', 'RecordingDuration']
    end

    def self.param_keys
      constant_param_keys + optional_param_keys + status_param_keys
    end

    def self.load(raw_params)
      raw_params.select{|k,v| param_keys.include?(k)}
    end
  end
end

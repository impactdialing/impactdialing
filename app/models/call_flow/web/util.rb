class CallFlow::Web::Util
  def self.filter(whitelisted_keys, data)
    return data if data.nil?
    
    data.select do |key,value|
      mapped_value = VoterList::VOTER_DATA_COLUMNS[key]
      whitelisted_keys.include?(mapped_value)
    end
  end

  def self.build_flags(whitelisted_keys = [])
    key_value_tuples = whitelisted_keys.map do |key|
      if VoterList::VOTER_DATA_COLUMNS.values.include?(key)
        ["#{key}_flag", true]
      end
    end
    key_value_tuples = key_value_tuples.empty? ? ['Phone_flag', true] : key_value_tuples
    Hash[ *key_value_tuples.compact.flatten ]
  end
end
class CallFlow::Web::Util
  def self.filter(whitelisted_keys, data)
    return data if data.nil?
    
    data.select do |key,value|
      if (mapped_value = VoterList::VOTER_DATA_COLUMNS[key]).blank?
        mapped_value = key
      end

      whitelisted_keys.include?(mapped_value)
    end
  end
end
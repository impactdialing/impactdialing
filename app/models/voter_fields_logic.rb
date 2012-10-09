module VoterFieldsLogic
  extend self

  UPLOAD_FIELDS = ["Phone", "CustomID", "LastName", "FirstName", "MiddleName", "Suffix", "Email", "address", "city", "state","zip_code", "country"]

  def selected_fields(voter, selection = nil)
    return [voter['Phone']] unless selection
    selection.select { |field| UPLOAD_FIELDS.include?(field) }.map { |field| voter[field] }
  end

  def selected_custom_fields(voter, selection)
    return [] unless selection
    query = CustomVoterField.where(account_id: voter['account_id'], name: selection).
      joins(:custom_voter_field_values).
      where(custom_voter_field_values: {voter_id: voter['id']}).
      group(:name).select([:name, :value]).to_sql
    voter_fields = Hash[*CustomVoterField.connection.execute(query).to_a.flatten]
    selection.map { |field| voter_fields[field] }
  end

end

shared_examples_for 'every Voter record imported' do
  it 'associates w/ created Household record' do
    subject.import_records
    expect(voter_records.all?{|record| record.household == household_record}).to be_truthy
  end
  it 'associates w/ proper Account record' do
    subject.import_records
    expect(voter_records.all?{|record| record.account == account}).to be_truthy
  end
  it 'associates w/ proper Campaign record' do
    subject.import_records
    expect(voter_records.all?{|record| record.campaign == campaign}).to be_truthy
  end
  it 'associates w/ proper VoterList record' do
    subject.import_records
    expect(voter_records.all?{|record| record.voter_list == voter_list}).to be_truthy
  end
  it 'stores its SQL ID with redis lead data' do
    expect(Wolverine.dial_queue).to receive(:update_leads_with_sql_id)
    subject.import_records
  end

  it "persists Voter system attributes" do
    aggregate_failures('Voter system attributes') do
      subject.import_records
      %w(first_name last_name middle_name suffix
       email address city state zip_code country).each do |field|
        expect(voter_records.last[field]).to eq households[phone][:leads].last[field.to_sym]
      end
    end
  end
end

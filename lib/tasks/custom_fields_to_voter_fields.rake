desc "Update twilio call data"

task :custom_fields_to_voter_fields => :environment do
  c = Campaign.find(674)
  c.all_voters.each do |voter|
    first_name_field = CustomVoterFieldValue.voter_fields(voter,CustomVoterField.find_by_name("fname")).first
    first_name = first_name_field ? first_name_field.value : nil
    last_name_field = CustomVoterFieldValue.voter_fields(voter,CustomVoterField.find_by_name("lname")).first
    last_name = last_name_field ? last_name_field.value : nil
    middle_name_field = CustomVoterFieldValue.voter_fields(voter,CustomVoterField.find_by_name("mname")).first
    middle_name = middle_name_field ? middle_name_field.value : nil
    voter.update_attributes(:FirstName => first_name, :LastName => last_name, :MiddleName => middle_name)
  end
end
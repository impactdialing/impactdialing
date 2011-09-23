desc "Update twilio call data"

task :clean_custom_voter_field_values => :environment do
  cc = Campaign.find(612)
  #cc = Campaign.find(1)
  c_field = cc.user.custom_voter_fields.find_by_name("VANID")

  myc = Campaign.find(474)
  #myc = Campaign.find(2)
  my_field = myc.user.custom_voter_fields.find_by_name("VANID")
  myc.all_voters.each do |voter|
    CustomVoterFieldValue.voter_fields(voter, my_field).each do |cvfv|
      vanid = cvfv.value
      phone = voter.Phone
      client_voter = cc.all_voters.find_by_Phone(phone)
      client_cvfv = CustomVoterFieldValue.find_by_custom_voter_field_id_and_value(c_field.id, vanid)
      client_cvfv.voter = client_voter
      client_cvfv.save
    end
  end

end

def go
  while true
    p CustomVoterFieldValue.count_by_sql 'select count(*) from custom_voter_field_values where voter_id is null'
    sleep 10
  end
end

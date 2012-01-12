desc "Update twilio call data"


task :download_report => :environment do
  report = get_report
  AWS::S3::Base.establish_connection!(
      :access_key_id => 'AKIAJCTCEHXW27SMQRHA',
      :secret_access_key => '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'
  )

  filename = "#{Rails.root}/tmp/report_#{@campaign.name}.csv"
  File.open(filename, "w") { |f| f.write report }
  p filename
  AWS::S3::S3Object.store("report_#{@campaign.name}.csv", File.open(filename), "impactdiallingapp", :content_type => "text/csv", :access=>'public-read')
end

def get_report
  c = Campaign.find(69)
  @campaign = c
  custom_fields = c.account.custom_voter_fields.collect { |field| field.name }
  campaign_notes = c.script.notes
  campaign_questions = c.script.questions

  report = CSV.generate do |csv|
    csv << [Voter.upload_fields, custom_fields, "Caller", "Status", "Call start", "Call end", "Attempts", "Recording", campaign_questions.collect { |q| q.text }, campaign_notes.collect { |note| note.note }].flatten
    c.all_voters.find_in_batches do |voters|
      voters.each do |v|
        voter_fields = v.selected_fields(Voter.upload_fields)
        voter_custom_fields = v.selected_custom_fields(custom_fields)

        last_call_attempt = v.last_call_attempt
        call_details = [last_call_attempt ? last_call_attempt.caller.try(:email) : '', v.status, last_call_attempt ? last_call_attempt.call_start.try(:in_time_zone, c.time_zone) : '', last_call_attempt ? last_call_attempt.call_end.try(:in_time_zone, c.time_zone) : '', v.call_attempts.size, last_call_attempt ? last_call_attempt.report_recording_url : ''].flatten
        notes, answers = [], []
        if last_call_attempt
          campaign_questions.each { |q| answers << v.answers.for(q).first.try(:possible_response).try(:value) }
          campaign_notes.each { |note| notes << v.note_responses.for(note).last.try(:response) }
          csv << [voter_fields, voter_custom_fields, call_details, answers, notes].flatten
        else
          csv << [voter_fields, voter_custom_fields, nil, "Not Dialed"].flatten
        end
      end
    end
  end
  return report
end
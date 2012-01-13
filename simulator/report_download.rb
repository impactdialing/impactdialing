RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')

def download
  @campaign = Campaign.find(91)
  csv = download_report
  @config = YAML::load(File.open("#{Rails.root}/config/amazon_s3.yml"))
  AWS::S3::Base.establish_connection!(
      :access_key_id     => @config["access_key_id"],
      :secret_access_key => @config["secret_access_key"]
    )    
  s3path="/download_campaign91_report.csv"
  AWS::S3::S3Object.store(s3path, csv, @config['bucket'],:content_type =>"application/text", :access => 'public-read')
  puts s3path
  
  # File.open("#{Rails.root}/tmp/nikhiloopopop.csv", 'w') {|f| f.write(csv) }
end

def download_report
  report = CSV.generate do |csv|
    selected_voter_fields = ["Phone", "CustomID" , "LastName", "FirstName","MiddleName", "Suffix", "Email", "address", "city",
                          "state", "zip_code", "country"]
    selected_custom_voter_fields = ["LD", "AL_AddrLine2", "SD", "UID", "AL_AddrLine1", "AL_City", "AL_State", "AL_Zip5"]
    csv << [selected_voter_fields ? selected_voter_fields : [], selected_custom_voter_fields ? selected_custom_voter_fields : [], "Caller", "Status", "Call start", "Call end", "Attempts", "Recording", @campaign.script.questions.collect { |q| q.text }, @campaign.script.notes.collect { |note| note.note }].flatten
    answers_from_voters = Answer.find_by_sql('select distinct voter_id from answers where campaign_id=91')
    voter_ids = answers_from_voters.collect{|answer| answer.voter_id}
    voters = Voter.where('id  in (?)', voter_ids)
    # voters = params[:download_all_voters] ? @campaign.all_voters : @campaign.all_voters.answered_within(@from_date, @to_date)
    i = 0
    voters.try(:each) do |v|
      puts "voter #{i}"
      i = i+1
      last_call_attempt = v.last_call_attempt
      
      notes, voter_custom_fields, answers, call_details = [], [], [], [last_call_attempt ? last_call_attempt.caller.try(:email) : '', v.status, last_call_attempt ? last_call_attempt.call_start.try(:in_time_zone, @campaign.time_zone) : '', last_call_attempt ? last_call_attempt.call_end.try(:in_time_zone, @campaign.time_zone) : '', v.call_attempts.size, last_call_attempt ? last_call_attempt.report_recording_url : ''].flatten
      voter_fields = selected_voter_fields ? [selected_voter_fields.try(:collect){|f| v.send(f)}].flatten : []
      custom_voter_field_objects = @campaign.account.custom_voter_fields.try(:select){|cf| selected_custom_voter_fields.try(:include?, cf.name)}
      custom_voter_field_objects.each { |cf| voter_custom_fields << v.custom_voter_field_values.for_field(cf).first.try(:value) }
      if last_call_attempt
        @campaign.script.questions.each { |q| answers << v.answers.for(q).first.try(:possible_response).try(:value) }
        @campaign.script.notes.each { |note| notes << v.note_responses.for(note).last.try(:response) }
        csv << [voter_fields, voter_custom_fields, call_details, answers, notes].flatten
      else
        csv << [voter_fields, voter_custom_fields, nil ,"Not Dialed"].flatten
      end
    end
  end
  report
end


download
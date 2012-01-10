class ReportJob < Struct.new(:campaign, :user, :selected_voter_fields, :selected_custom_voter_fields, :download_all_voters, :from_date, :to_date)
  def perform
    #report = CSV.generate do |csv|
    #  csv << [selected_voter_fields ? selected_voter_fields : [], selected_custom_voter_fields ? selected_custom_voter_fields : [], "Caller", "Status", "Call start", "Call end", "Attempts", "Recording", campaign.script.questions.collect { |q| q.text }, campaign.script.notes.collect { |note| note.note }].flatten
    #  voters = download_all_voters ? campaign.all_voters : campaign.all_voters.answered_within(from_date, to_date)
    #
    #
    #  voters.try(:each) do |v|
    #    last_call_attempt = v.last_call_attempt
    #
    #    notes, voter_custom_fields, answers, call_details = [], [], [], [last_call_attempt ? last_call_attempt.caller.try(:email) : '', v.status, last_call_attempt ? last_call_attempt.call_start.try(:in_time_zone, @campaign.time_zone) : '', last_call_attempt ? last_call_attempt.call_end.try(:in_time_zone, @campaign.time_zone) : '', v.call_attempts.size, last_call_attempt ? last_call_attempt.report_recording_url : ''].flatten
    #    voter_fields = selected_voter_fields ? [selected_voter_fields.try(:collect){|f| v.send(f)}].flatten : []
    #    custom_voter_field_objects = @campaign.account.custom_voter_fields.try(:select){|cf| selected_custom_voter_fields.try(:include?, cf.name)}
    #    custom_voter_field_objects.each { |cf| voter_custom_fields << v.custom_voter_field_values.for_field(cf).first.try(:value) }
    #    if last_call_attempt
    #      @campaign.script.questions.each { |q| answers << v.answers.for(q).first.try(:possible_response).try(:value) }
    #      @campaign.script.notes.each { |note| notes << v.note_responses.for(note).last.try(:response) }
    #      csv << [voter_fields, voter_custom_fields, call_details, answers, notes].flatten
    #    else
    #      csv << [voter_fields, voter_custom_fields, nil ,"Not Dialed"].flatten
    #    end
    #  end
    #end


  end

end

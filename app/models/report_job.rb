class ReportJob < Struct.new(:campaign, :user, :selected_voter_fields, :selected_custom_voter_fields, :download_all_voters, :from_date, :to_date)
  def save_report
    AWS::S3::Base.establish_connection!(
        :access_key_id => 'AKIAINGDKRFQU6S63LUQ',
        :secret_access_key => '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'
    )

    FileUtils.mkdir_p(Rails.root.join("tmp"))
    filename = "#{Rails.root}/tmp/report_#{campaign.name}.csv"
    File.open(filename, "w") { |f| f.write @report }
    AWS::S3::S3Object.store("report_#{campaign.name}.csv", File.open(filename), "download_reports", :content_type => "text/csv", :access=>'public-read')
    mailer = UserMailer.new
    mailer.deliver_download(user, AWS::S3::S3Object.url_for("report_#{campaign.name}.csv", "download_reports"))
  end

  def perform
    @campaign_notes = campaign.script.notes
    @campaign_questions = campaign.script.questions
    @report = CSV.generate do |csv|
      csv << [selected_voter_fields.try(:compact), selected_custom_voter_fields.try(:compact), "Caller", "Status", "Call start", "Call end", "Attempts", "Recording", @campaign_questions.collect { |q| q.text }, @campaign_notes.collect { |note| note.note }].flatten
      if download_all_voters
        campaign.all_voters.find_in_batches(:batch_size => 2000) { |voters| voters.each { |v| csv << csv_for(v) } }
      else
        campaign.all_voters.answered_within(from_date, to_date).find_in_batches(:batch_size => 2000) { |voters| voters.each { |v| csv << csv_for(v) } }
      end
    end
    save_report
  end

  def csv_for(voter)
    csv, notes, answers = [], [], []
    voter_fields = voter.selected_fields(selected_voter_fields.compact)

    last_call_attempt = voter.last_call_attempt
    call_details = [last_call_attempt ? last_call_attempt.caller.try(:name)||last_call_attempt.caller.try(:email) : '', voter.status, last_call_attempt ? last_call_attempt.call_start.try(:in_time_zone, campaign.time_zone) : '', last_call_attempt ? last_call_attempt.call_end.try(:in_time_zone, campaign.time_zone) : '', voter.call_attempts.size, last_call_attempt ? last_call_attempt.report_recording_url : ''].flatten
    if last_call_attempt
      @campaign_questions.each { |q| answers << voter.answers.for(q).first.try(:possible_response).try(:value) }
      @campaign_notes.each { |note| notes << voter.note_responses.for(note).last.try(:response) }
      csv << [voter_fields, voter.custom_fields, call_details, answers, notes].flatten
    else
      csv << [voter_fields, voter.custom_fields, nil, "Not Dialed"].flatten
    end
    csv.flatten
  end

end

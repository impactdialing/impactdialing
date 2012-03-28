class ReportJob < Struct.new(:campaign, :user, :selected_voter_fields, :selected_custom_voter_fields, :download_all_voters, :from_date, :to_date)
  

  def initialize(campaign, user, voter_fields, custom_fields, all_voters, from, to)
    voter_fields = ["Phone"] if voter_fields.blank?
    super(campaign, user, voter_fields, custom_fields, all_voters, from, to)
  end

  def save_report
    AWS::S3::Base.establish_connection!(
        :access_key_id => 'AKIAINGDKRFQU6S63LUQ',
        :secret_access_key => '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'
    )

    FileUtils.mkdir_p(Rails.root.join("tmp"))
    uuid = UUID.new.generate
    @campaign_name = "#{uuid}_report_#{campaign.name}"
    # @campaign_name = @campaign_name.tr("/\000", "")
    filename = "#{Rails.root}/tmp/#{@campaign_name}.csv"
    report_csv = @report.split("\n")
    file = File.open(filename, "w")
    report_csv.each do |r|
      begin
        file.write(r)
        file.write("\n")
      rescue Exception => e
        puts e
        next
      end      
    end
    file.close    
    expires_in_12_hours = (Time.now + 12.hours).to_i
    AWS::S3::S3Object.store("#{@campaign_name}.csv", File.open(filename), "download_reports", :content_type => "application/binary", :access=>:private, :expires => expires_in_12_hours)
  end

  def perform
    @campaign_strategy = campaign.robo ? BroadcastStrategy.new(campaign) : CallerStrategy.new(campaign)
    @report = CSV.generate do |csv|
      csv << @campaign_strategy.csv_header(selected_voter_fields, selected_custom_voter_fields)
      if download_all_voters
        campaign.all_voters.find_in_batches(:batch_size => 2000) { |voters| voters.each { |v| csv << csv_for(v) } }
      else
        campaign.all_voters.answered_within_timespan(from_date, to_date).find_in_batches(:batch_size => 2000) { |voters| voters.each { |v| csv << csv_for(v) } }
      end
    end
    save_report
    
  end

  def csv_for(voter)
    voter_fields = voter.selected_fields(selected_voter_fields.try(:compact))
    custom_fields = voter.selected_custom_fields(selected_custom_voter_fields)
    [voter_fields, custom_fields, @campaign_strategy.call_details(voter)].flatten
  end

  def after(job)
    notify_success
  end

  def error(job, exception)
    notify_failure(job, exception)
  end

  def notify_success
    mailer = UserMailer.new
    expires_in_12_hours = (Time.now + 12.hours).to_i
    mailer.deliver_download(user, AWS::S3::S3Object.url_for("#{@campaign_name}.csv", "download_reports", :expires => expires_in_12_hours))
  end

  def notify_failure(job, exception)
    mailer = UserMailer.new
    mailer.deliver_download_failure(user, campaign, job, exception)
  end

end

class CampaignStrategy
  def initialize(campaign)
    @campaign = campaign
  end
end


class CallerStrategy < CampaignStrategy
  def csv_header(fields, custom_fields)
    [fields, custom_fields, "Caller", "Status", "Call start", "Call end", "Attempts", "Recording", @campaign.script.questions.collect { |q| q.text }, @campaign.script.notes.collect { |note| note.note }].flatten.compact
  end

  def call_details(voter)
    answers, notes = [], []
    last_attempt = voter.call_attempts.last
    details = if last_attempt
                [last_attempt.try(:caller).try(:known_as), voter.status, last_attempt.try(:call_start).try(:in_time_zone, @campaign.time_zone), last_attempt.try(:call_end).try(:in_time_zone, @campaign.time_zone), voter.call_attempts.size, last_attempt.try(:report_recording_url)].flatten
              else
                [nil, "Not Dialed","","","",""]
              end
    @campaign.script.questions.each { |q| answers << voter.answers.for(q).first.try(:possible_response).try(:value) }
    @campaign.script.notes.each { |note| notes << voter.note_responses.for(note).last.try(:response) }
    [details, answers, notes].flatten
  end
end

class BroadcastStrategy < CampaignStrategy
  def csv_header(fields, custom_fields)
    [fields, custom_fields, "Status", @campaign.script.robo_recordings.collect { |rec| rec.name }].flatten.compact
  end

  def call_details(voter)
    last_attempt = voter.call_attempts.last
    details = last_attempt ? [last_attempt.status, (last_attempt.call_responses.collect { |call_response| call_response.recording_response.try(:response) } if last_attempt.call_responses.size > 0)].flatten : ['Not Dialed']
    details
  end
end

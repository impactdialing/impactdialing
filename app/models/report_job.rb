class ReportJob 
  
  module AttemptStatus
    ANSWERED = "Answered"
    ABANDONED = "Abandoned"
    FAILED = "Failed"
    BUSY = "Busy"
    NOANSWER = 'No answer'
    ANSWERING_MACHINE = "Answering machine"
    ANSWERING_MACHINE_MESSAGE = "Answering machine message delivered"
    SCHEDULED = 'Scheduled for later'
    NOT_DIALED = "Not Dialed"
  end
  
  
  
  def self.map_status(status)
    statuses = {CallAttempt::Status::SUCCESS => AttemptStatus::ANSWERED, Voter::Status::RETRY => AttemptStatus::ANSWERED, 
      Voter::Status::NOTCALLED => AttemptStatus::NOT_DIALED, CallAttempt::Status::NOANSWER => AttemptStatus::NOANSWER, 
      CallAttempt::Status::ABANDONED => AttemptStatus::ABANDONED, CallAttempt::Status::BUSY => AttemptStatus::BUSY,
      CallAttempt::Status::FAILED => AttemptStatus::FAILED, CallAttempt::Status::HANGUP => AttemptStatus::ANSWERING_MACHINE,
      CallAttempt::Status::SCHEDULED => AttemptStatus::SCHEDULED, CallAttempt::Status::VOICEMAIL => AttemptStatus::ANSWERING_MACHINE_MESSAGE}
      statuses[status] || status
  end
  
  
  def initialize(campaign_id, user_id, voter_fields, custom_fields, all_voters, lead_dial, from, to, callback_url, strategy="webui")
    @campaign = Campaign.find(campaign_id)
    @user = User.find(user_id)
    @selected_voter_fields = voter_fields
    @selected_custom_voter_fields = custom_fields
    @download_all_voters = all_voters
    @lead_dial = lead_dial
    @from_date = from
    @to_date = to
    @callback_url = callback_url
    @strategy = strategy
    @selected_voter_fields = ["Phone"] if @selected_voter_fields.blank?
  end

  def save_report
    AWS::S3::Base.establish_connection!(
        :access_key_id => 'AKIAINGDKRFQU6S63LUQ',
        :secret_access_key => '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'
    )

    FileUtils.mkdir_p(Rails.root.join("tmp"))
    uuid = UUID.new.generate
    @campaign_name = "#{uuid}_report_#{@campaign.name}"
    @campaign_name = @campaign_name.tr("/\000", "")
    filename = "#{Rails.root}/tmp/#{@campaign_name}.csv"
    report_csv = @report.split("\n")
    puts "Writing to file: #{report_csv.size}"
    file = File.open(filename, "w")
    report_csv.each do |r|
      begin
        file.write(r)
        file.write("\n")
      rescue Exception => e
        puts "row from report"
        puts r
        puts e
        next
      end      
    end
    file.close    
    expires_in_24_hours = (Time.now + 24.hours).to_i
    AWS::S3::S3Object.store("#{@campaign_name}.csv", File.open(filename), "download_reports", :content_type => "application/binary", :access=>:private, :expires => expires_in_24_hours)
  end

  def perform
    begin
      @campaign_strategy = @campaign.robo ? BroadcastStrategy.new(@campaign) : CallerStrategy.new(@campaign)    
      question_ids = Answer.all(:select=>"distinct question_id", :conditions=>"campaign_id = #{@campaign.id}", :order => "question_id").collect{|a| a.question_id}
      note_ids = NoteResponse.all(:select=>"distinct note_id", :conditions=>"campaign_id = #{@campaign.id}", :order => "note_id").collect{|nr| nr.note_id }    
      @report = CSV.generate do |csv|
        csv << @campaign_strategy.csv_header(@selected_voter_fields, @selected_custom_voter_fields, question_ids, note_ids)
        if @download_all_voters
          if @lead_dial == "dial"
            @campaign.call_attempts.find_in_batches(:batch_size => 10) { |attempts| attempts.each { |a| csv << csv_for_call_attempt(a, question_ids, note_ids) } }
          else
            @campaign.all_voters.find_in_batches(:batch_size => 10) { |voters| voters.each { |v| csv << csv_for(v, question_ids, note_ids) } }
          end        
        else
          if @lead_dial == "dial"
            @campaign.call_attempts.between(@from_date, @to_date).find_in_batches(:batch_size => 10) { |call_attempts| call_attempts.each { |a| csv << csv_for_call_attempt(a, question_ids, note_ids) } }
          else
            @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).find_in_batches(:batch_size => 10) { |voters| voters.each { |v| csv << csv_for(v, question_ids, note_ids) } }
          end
        
        end
      end
    rescue Exception => e
      puts e
      puts e.backtrace
    end
    save_report
    
  end

  def csv_for(voter, question_ids, note_ids)
    puts "Voter_ID: #{voter.id}"
    voter_fields = voter.selected_fields(@selected_voter_fields.try(:compact))
    custom_fields = voter.selected_custom_fields(@selected_custom_voter_fields)
    [voter_fields, custom_fields, @campaign_strategy.call_details(voter, question_ids, note_ids)].flatten
  end
  
  def csv_for_call_attempt(call_attempt, question_ids, note_ids)
    puts "CallAttempt_ID: #{call_attempt.id}"
    voter = call_attempt.voter
    voter_fields = voter.selected_fields(@selected_voter_fields.try(:compact))
    custom_fields = voter.selected_custom_fields(@selected_custom_voter_fields)
    [voter_fields, custom_fields, @campaign_strategy.call_attempt_details(call_attempt, voter, question_ids, note_ids)].flatten
  end
  

  def after(job)
    notify_success
  end

  def error(job, exception)
    notify_failure(job, exception)
  end

  def notify_success
    response_strategy = @strategy == 'webui' ?  ReportWebUIStrategy.new("success", @user, @campaign, nil, nil) : ReportApiStrategy.new("success", @campaign.id, @campaign.account.id, @callback_url)
    response_strategy.response({campaign_name: @campaign_name})
  end

  def notify_failure(job, exception)
    response_strategy = @strategy == 'webui' ?  ReportWebUIStrategy.new("failure", @user, @campaign, job, exception) : ReportApiStrategy.new("failure", @campaign.id, @campaign.account.id, @callback_url)
    response_strategy.response({})
  end

end

class CampaignStrategy
  def initialize(campaign)
    @campaign = campaign
  end
end


class CallerStrategy < CampaignStrategy
  def csv_header(fields, custom_fields, question_ids, note_ids)
    modified_questions = []
    modified_notes = []
    questions = Question.select("id, text").where("id in (?)",question_ids).order('id')
    
    question_ids.each_with_index do |question_id, index|
      unless questions.collect{|x| x.id}.include?(question_id)
        modified_questions << Question.new(text: "")
      else
        modified_questions << Question.new(text: questions.detect{|at| at.id == question_id}.text)
      end
    end
    
    notes = Note.select("id, note").where("id in (?)",note_ids).order('id')
    
    note_ids.each_with_index do |note_id, index|
      unless notes.collect{|x| x.id}.include?(note_id)
        modified_notes << Note.new(note: "")
      else
        modified_notes << Note.new(note: notes.detect{|at| at.id == note_id}.note)
      end
    end
    
    
    [fields, custom_fields, "Caller", "Status", "Call start", "Call end", "Attempts", "Recording", modified_questions.collect{|m_q| m_q.text}, modified_notes.collect{|m_n| m_n.note}].flatten.compact
  end
  
  def call_attempt_details(call_attempt, voter, question_ids, note_ids)
    answers, notes = [], []
    details = [call_attempt.try(:caller).try(:known_as), ReportJob.map_status(call_attempt.status), call_attempt.try(:call_start).try(:in_time_zone, @campaign.time_zone), call_attempt.try(:call_end).try(:in_time_zone, @campaign.time_zone), 1, call_attempt.try(:report_recording_url)].flatten
    answers = call_attempt.answers.for_questions(question_ids).order('question_id')
    note_responses = call_attempt.note_responses.for_notes(note_ids).order('note_id')
    answer_texts = PossibleResponse.select("question_id, value").where("id in (?)", answers.collect{|a| a.try(:possible_response).try(:id) } ).order('question_id')
    modified_answers = []
    modified_notes = []
    
    question_ids.each_with_index do |question_id, index|
      unless answer_texts.collect{|x| x.question_id}.include?(question_id)
        modified_answers << PossibleResponse.new(value: "")
      else
        modified_answers << PossibleResponse.new(value: answer_texts.detect{|at| at.question_id == question_id}.value)
      end
    end
    
      note_ids.each_with_index do |note_id, index|
        unless note_responses.collect{|x| x.note_id}.include?(note_id)
          modified_notes << NoteResponse.new(response: "")
        else
          modified_notes << NoteResponse.new(response: note_responses.detect{|at| at.note_id == note_id}.response)
        end
      end
    
    [details, modified_answers.collect{|at| at.value}, modified_notes.collect{|n| n.response}].flatten    
  end

  def call_details(voter, question_ids, note_ids)
    answers, notes = [], []
    last_attempt = voter.call_attempts.last
    details = if last_attempt
                [last_attempt.try(:caller).try(:known_as), ReportJob.map_status(voter.status), last_attempt.try(:call_start).try(:in_time_zone, @campaign.time_zone), last_attempt.try(:call_end).try(:in_time_zone, @campaign.time_zone), voter.call_attempts.size, last_attempt.try(:report_recording_url)].flatten
              else
                [nil, "Not Dialed","","","",""]
              end
    if last_attempt          
      answers = last_attempt.answers.for_questions(question_ids).order('question_id')
      answer_texts = PossibleResponse.select("question_id, value").where("id in (?)", answers.collect{|a| a.try(:possible_response).try(:id) } ).order('question_id')
      modified_answers = []
      modified_notes = []
      question_ids.each_with_index do |question_id, index|
        unless answer_texts.collect{|x| x.question_id}.include?(question_id)
          modified_answers << PossibleResponse.new(value: "")
        else
          modified_answers << PossibleResponse.new(value: answer_texts.detect{|at| at.question_id == question_id}.value)
        end
      end
      notes = last_attempt.note_responses.for_notes(note_ids).order('note_id')   
      note_ids.each_with_index do |note_id, index|
        unless note_responses.collect{|x| x.note_id}.include?(note_id)
          modified_notes << NoteResponse.new(response: "")
        else
          modified_notes << NoteResponse.new(response: note_responses.detect{|at| at.note_id == note_id}.response)
        end
      end           
    else
      modified_answers = []
      modified_notes = []
    end
    [details, modified_answers.collect{|at| at.value}, modified_notes.collect{|n| n.response}].flatten
  end
end

class BroadcastStrategy < CampaignStrategy
  def csv_header(fields, custom_fields, question_ids, note_ids)
    [fields, custom_fields, "Status", @campaign.script.robo_recordings.collect { |rec| rec.name }].flatten.compact
  end
  
  def call_attempt_details(call_attempt, voter, question_ids, note_ids)
    [call_attempt.status, (call_attempt.call_responses.collect { |call_response| call_response.recording_response.try(:response) } if call_attempt.call_responses.size > 0)].flatten
  end

  def call_details(voter, question_ids, note_ids)
    last_attempt = voter.call_attempts.last
    details = last_attempt ? [last_attempt.status, (last_attempt.call_responses.collect { |call_response| call_response.recording_response.try(:response) } if last_attempt.call_responses.size > 0)].flatten : ['Not Dialed']
    details
  end
end

class ReportWebUIStrategy
  
  def initialize(result, user, campaign, job, exception)
    @result = result
    @mailer = UserMailer.new    
    @user = user
    @campaign = campaign
    @job = job
    @exception = exception
  end

    
  def response(params)
    if @result == "success"
      expires_in_24_hours = (Time.now + 24.hours).to_i
      link = AWS::S3::S3Object.url_for("#{params[:campaign_name]}.csv", "download_reports", :expires => expires_in_24_hours)
      DownloadedReport.create(link: link, user: @user, campaign_id: @campaign.id)
      @mailer.deliver_download(@user, link)
    else
      @mailer.deliver_download_failure(@user, @campaign, @job, @exception)
    end
  end
  
end


class ReportApiStrategy
  require 'net/http'
  
  def initialize(result, account_id, campaign_id, callback_url)
    @result = result
    @account_id = account_id
    @campaign_id = campaign_id
    @callback_url = callback_url
  end
  
  def response(params)
    if @result == "success"
      link = AWS::S3::S3Object.url_for("#{params[:campaign_name]}.csv", "download_reports", :expires => expires_in_12_hours)
    else
      link = ""
    end
    uri = URI.parse(@callback_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl=true
    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data({message: @result, download_link: link, account_id: @account_id, campaign_id: @campaign_id})
    http.start{http.request(request)}
  end
  
end

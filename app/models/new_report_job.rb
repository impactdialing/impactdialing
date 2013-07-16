require 'octopus'
class NewReportJob
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

   def report_strategy(csv)
     CallerCampaignReportStrategy.new(@campaign, csv, @download_all_voters, @lead_dial, @selected_voter_fields, @selected_custom_voter_fields, @from_date, @to_date)
   end

  def perform
    begin
        @report = CSV.generate do |csv|
          @campaign_strategy = report_strategy(csv)
          @campaign_strategy.construct_csv
        end
      save_report
      notify_success
    rescue Exception => e
      on_failure_report(e)
      raise e
    end
  end

  def notify_success
    response_strategy = @strategy == 'webui' ?  ReportWebUIStrategy.new("success", @user, @campaign, nil) : ReportApiStrategy.new("success", @campaign.account.id, @campaign.id, @callback_url)
    response_strategy.response({campaign_name: @campaign_name})
  end

   def on_failure_report(exception)
      response_strategy = @strategy == 'webui' ?  ReportWebUIStrategy.new("failure", @user, @campaign, exception) : ReportApiStrategy.new("failure", @campaign.account.id, @campaign.id, @callback_url)
      response_strategy.response({})
   end


   def file_name
    FileUtils.mkdir_p(Rails.root.join("tmp"))
    uuid = UUID.new.generate
    @campaign_name = "#{uuid}_report_#{@campaign.name}"
    @campaign_name = @campaign_name.tr("/\000", "").tr("'","_").tr("-","_").tr(" ", "")
    "#{Rails.root}/tmp/#{@campaign_name}.csv"
   end

   def save_report
     csv_file_name = file_name
     write_csv_to_file(csv_file_name)
     AmazonS3.new.write_report("#{@campaign_name}.csv", csv_file_name)
   end

   def write_csv_to_file(csv_file_name)
     report_csv = @report.split("\n")
     file = File.open(csv_file_name, "w")
     report_csv.each do |r|
       begin
         file.write(r)
         file.write("\n")
       rescue Exception => e
         next
       end
     end
     file.close
   end

end

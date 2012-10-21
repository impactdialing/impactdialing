class VoterListJob
  def initialize(voter_list_id, domain, email, callback_url, strategy="webui")
    @voter_list = VoterList.find(voter_list_id)
    @separator = @voter_list.separator
    @csv_to_system_map = CsvMapping.new(JSON.load(@voter_list.csv_to_system_map))
    @csv_filename = @voter_list.s3path
    @voter_list_name = @voter_list.name
    @voter_list_campaign_id = @voter_list.campaign_id
    @voter_list_account_id = @voter_list.account_id
    @domain = domain
    @email = email
    @strategy = strategy
    @callback_url = callback_url
  end

  def perform
    response_strategy = @strategy == 'webui' ?  VoterListWebuiStrategy.new : VoterListApiStrategy.new(@voter_list_account_id, @voter_list_campaign_id, @callback_url)
    response = {"errors"=> [], "success"=> []}
    user_mailer = UserMailer.new

    unless @csv_to_system_map.valid?
      response["errors"].concat(@csv_to_system_map.errors)
      response_strategy.response(response, {domain: @domain, email: @email, voter_list_name: @voter_list_name})
      return response
    end

    begin
      result = @voter_list.import_leads(@csv_to_system_map,
                                        @csv_filename,
                                        @separator)
      response['success'] << "Upload complete. #{result[:successCount]} out of #{result[:successCount]+result[:failedCount]} records imported successfully."
    rescue Exception => err
      @voter_list.destroy_with_voters
      response['errors'] << "Invalid CSV file. Could not import."
    ensure
      VoterList.delete_from_s3 @csv_filename
      response_strategy.response(response, {domain: @domain, email: @email, voter_list_name: @voter_list_name})
      return response
    end
  end

end

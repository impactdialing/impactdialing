class VoterListJob
  def initialize(separator, csv_to_system_map, filename, voter_list_name, campaign_id, account_id, domain, email,callback_url,strategy="webui")
    @separator = separator
    @csv_to_system_map = CsvMapping.new(csv_to_system_map)
    @csv_filename = filename
    @voter_list_name = voter_list_name
    @voter_list_campaign_id = campaign_id
    @voter_list_account_id = account_id
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

    @voter_list = VoterList.new(name: @voter_list_name, campaign_id: @voter_list_campaign_id, account_id: @voter_list_account_id)

    unless @voter_list.valid?
      response['errors'] << @voter_list.errors.full_messages.join("; ")
      response_strategy.response(response, {domain: @domain, email: @email, voter_list_name: @voter_list_name})
      return response
    end
    @voter_list.save!

    begin
      result = @voter_list.import_leads(@csv_to_system_map,
                                        @csv_filename,
                                        @separator)
      response['success'] << "Upload complete. #{result[:successCount]} out of #{result[:successCount]+result[:failedCount]} records imported successfully."
    rescue Exception => err
      @voter_list.destroy
      response['errors'] << "Invalid CSV file. Could not import."
    ensure
      VoterList.delete_from_s3 @csv_filename
      response_strategy.response(response, {domain: @domain, email: @email, voter_list_name: @voter_list_name})
      return response
    end
  end

end

class VoterListJob
  def initialize(separator, column_headers, csv_to_system_map, filename, voter_list_name, campaign_id, account_id, domain, email)
    @separator = separator
    @csv_column_headers = JSON.parse(column_headers)
    @csv_to_system_map = CsvMapping.new(csv_to_system_map)
    @csv_filename = filename
    @voter_list_name = voter_list_name
    @voter_list_campaign_id = campaign_id
    @voter_list_account_id = account_id
    @domain = domain
    @email = email
  end

  def perform
    response = {"errors"=> [], "success"=> []}
    user_mailer = UserMailer.new

    unless @csv_to_system_map.valid?
      response["errors"].concat(@csv_to_system_map.errors)
      user_mailer.voter_list_upload(response, @domain, @email)
      return response
    end

    @voter_list = VoterList.new(name: @voter_list_name, campaign_id: @voter_list_campaign_id, account_id: @voter_list_account_id)

    unless @voter_list.valid?
      response['errors'] << @voter_list.errors.full_messages.join("; ")
      user_mailer.voter_list_upload(response, @domain, @email,@voter_list_name)
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
      user_mailer.voter_list_upload(response, @domain, @email, @voter_list_name)
      return response
    end
  end

end

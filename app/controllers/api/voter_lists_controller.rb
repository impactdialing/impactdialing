require Rails.root.join("jobs/voter_list_upload_job")
module Api
  class VoterListsController < ApiController
    
    def validate_list_file_format(upload)
      upload = params[:upload].try(:[],"datafile")
      unless VoterList.valid_file?(upload.try(:original_filename))
        render_json_response({status: 'error', code: '400' , message: 'Wrong file format. Please upload a comma-separated value (CSV) or tab-delimited text (TXT) file. If your list is in Excel format (XLS or XLSX), use \"Save As\" to change it to one of these formats.'})
        return false
      end      
      return true
    end
    
    def validate_params
      validate_campaign(params[:campaign_id]) && validate_account(params[:account_id]) && validate_campaign_belongs_to_account(params[:campaign_id], params[:account_id]) && validate_email_belongs_to_account(params[:account_id], params[:email]) && validate_list_file_format(params[:upload])      
    end
    
    
    def create
      return unless validate_params      
      upload = params[:upload].try(:[],"datafile")
      csv = upload.read
      csv_filename = "#{upload.original_filename}_#{Time.now.to_i}_#{rand(999)}"
      saved_file_name = VoterList.upload_file_to_s3(csv, csv_filename)
      separator = VoterList.separator_from_file_extension(upload.original_filename)      
      begin
        csv_column_headers = CSV.new(csv, :col_sep => separator).shift.collect{|h| h.blank? ? VoterList::BLANK_HEADER : h}
      rescue Exception => err
        render_json_response({status: 'error', code: '400' , message: I18n.t(:invalid_file_uploaded)})
        return
      end
      user = User.find_by_email(params[:email]) 
      account = Account.find(params[:account_id])
      Resque.enqueue(VoterListUploadJob, separator, csv_column_headers.to_json, VoterList.create_csv_to_system_map(csv_column_headers, account), saved_file_name, params[:voter_list_name], params[:campaign_id], params[:account_id],user.domain, params[:email],params[:callback_url], "api")
      render_json_response({status: 'ok', code: '200' , message: "Response will be sent to the callback url once the list upload is complete."})
    end
    
  end
end  

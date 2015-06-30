require 'resque/errors'
require 'librato_resque'

##
# Upload a new +VoterList+, importing +Voter+ records.
#
# Files uploaded to S3 are kept there until cleaned by +VoterListS3Scrub+ (see resque schedule).
#
# ### Metrics
#
# - completed
# - failed
# - timing
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 failure
#
class VoterListUploadJob
  extend LibratoResque

  @queue = :dial_queue

  def self.response_template
    {"errors" => [], "success" => []}
  end

  def self.handle_errors(responder, errors, domain, email, voter_list)
    tpl = response_template.dup
    tpl["errors"].concat([*errors])
    submit_response!(responder, tpl, domain, email, voter_list)
  end

  def self.handle_success(responder, result, domain, email, voter_list)
    tpl           = response_template.dup
    dnc_count     = result[:dnc]
    success_count = result[:success]
    fail_count    = result[:failed]
    cell_count    = result[:cell]
    import_count  = success_count + dnc_count
    total_count   = success_count + fail_count

    tpl['success'] << [
      "Upload complete.",
      " #{success_count} out of #{total_count} records imported successfully.",
      " #{dnc_count} out of #{success_count} records contained phone numbers",
      " in your Do Not Call list. #{cell_count} records were skipped because they are assigned to cellular devices."
    ].join
    submit_response!(responder, tpl, domain, email, voter_list)
  end

  def self.submit_response!(responder, response, domain, email, voter_list)
    Rails.logger.debug "#{self}: submit_response! #{response}"
    responder.response(response, {domain: domain, email: email, voter_list_name: voter_list.name})
  end

  def self.parse_csv(responder, domain, email, voter_list)
    begin
      csv_file = CSV.new(VoterList.read_from_s3(voter_list.s3path), :col_sep => voter_list.separator)
      # parse now to surface any CSV issues early
      headers  = csv_file.shift
      data     = csv_file.readlines
    rescue CSV::MalformedCSVError => err
      Rails.logger.error "Caught CSV::MalformedCSVError #{err.message}. Destroying VoterList[#{voter_list.name}] for Account[#{voter_list.account_id}] on Campaign[#{voter_list.campaign_id}] at S3path[#{voter_list.s3path}]"
      errors = [I18n.t('csv_validator.malformed')]
      handle_errors(responder, errors, domain, email, voter_list)
      return []
    end
    return [headers, data]
  end

  def self.perform(voter_list_id, email, domain)
    ActiveRecord::Base.clear_active_connections!

    begin
      voter_list  = VoterList.find(voter_list_id)
      responder   = VoterListWebuiStrategy.new
      csv_mapping = CsvMapping.new(voter_list.csv_to_system_map)

      unless csv_mapping.valid?
        handle_errors(responder, csv_mapping.errors, domain, email, voter_list)
        return false
      end

      headers, data = parse_csv(responder, domain, email, voter_list)
      if headers.nil? or data.nil?
        handle_errors(responder, "No data found in uploaded file.", domain, email, voter_list)
        return false
      end

      # import voters
      batch_upload = VoterBatchImport.new(voter_list, csv_mapping, headers, data)
      begin
        result       = batch_upload.import_csv
      rescue ActiveRecord::StatementInvalid, Mysql2::Error => exception
        Rails.logger.error "VoterListUploadJob Failed. Destroying Voters & VoterList. Campaign[#{voter_list.campaign_id}] Error: #{exception.message}"

        error_msg = I18n.t('activerecord.errors.models.voter_list.general_error')

        handle_errors(responder, error_msg, domain, email, voter_list)
        voter_list.voters.destroy_all
        voter_list.destroy
        return false
      end

      # build & email import results
      handle_success(responder, result, domain, email, voter_list)

      Resque.enqueue(ResetVoterListCounterCache, voter_list_id)
    rescue Resque::TermException
      # we are re-queueing so make sure to not duplicate voters
      Rails.logger.info "Caught Resque::TermException. Destroying #{voter_list.voters.count} Voter records and re-queueing."
      voter_list.voters.destroy_all
      Resque.enqueue(self, voter_list_id, email, domain)
      raise
    end
  end
end

class VoterListWebuiStrategy
  def initialize
    @user_mailer = UserMailer.new
  end

  def response(response, params)
    @user_mailer.voter_list_upload(response, params[:domain], params[:email],params[:voter_list_name])
  end
end

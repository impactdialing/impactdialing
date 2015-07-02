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

  def self.mailer(email, voter_list)
    VoterListMailer.new(email, voter_list)
  end

  def self.handle_errors(errors, email, voter_list)
    mailer(email, voter_list).failed(errors)
  end

  def self.handle_success(results, email, voter_list)
    mailer(email, voter_list).completed(results)
  end

  def self.parse_csv(email, voter_list)
    begin
      csv_file = CSV.new(VoterList.read_from_s3(voter_list.s3path), :col_sep => voter_list.separator)
      # parse now to surface any CSV issues early
      headers  = csv_file.shift
      data     = csv_file.readlines
    rescue CSV::MalformedCSVError => err
      Rails.logger.error "Caught CSV::MalformedCSVError #{err.message}. Destroying VoterList[#{voter_list.name}] for Account[#{voter_list.account_id}] on Campaign[#{voter_list.campaign_id}] at S3path[#{voter_list.s3path}]"
      errors = [I18n.t('csv_validator.malformed')]
      handle_errors(errors, email, voter_list)

      return []
    end
    return [headers, data]
  end

  def self.perform(voter_list_id, email, domain)
    ActiveRecord::Base.clear_active_connections!

    begin
      voter_list  = VoterList.find(voter_list_id)
      csv_mapping = CsvMapping.new(voter_list.csv_to_system_map)

      unless csv_mapping.valid?
        handle_errors(csv_mapping.errors, email, voter_list)
        return false
      end

      headers, data = parse_csv(email, voter_list)
      if headers.nil? or data.nil?
        handle_errors(["No data found in uploaded file."], email, voter_list)
        return false
      end

      # import voters
      batch_upload = VoterBatchImport.new(voter_list, csv_mapping, headers, data)
      begin
        result = batch_upload.import_csv
      rescue ActiveRecord::StatementInvalid, Mysql2::Error => exception
        Rails.logger.error "VoterListUploadJob Failed. Destroying Voters & VoterList. Campaign[#{voter_list.campaign_id}] Error: #{exception.message}"

        error_msg = I18n.t('activerecord.errors.models.voter_list.general_error')

        handle_errors([error_msg], email, voter_list)
        voter_list.voters.destroy_all
        voter_list.destroy
        return false
      end

      # build & email import results
      handle_success(result, email, voter_list)

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

require 'csv'

namespace :export do

  def export_and_save_csv(records, filename, account_id)
    sample = records.first
    if sample.nil?
      sample = records.last
      if sample.nil?
        p "Skipping #{records.count} records due to nil sample for file: #{filename} - #{records}"
        return
      end
    end
    headers = sample.attributes.keys

    export = CSV.generate({
      headers: headers,
      write_headers: true,
      force_quotes: true
    }) do |csv|
      records.each do |record|
        csv << record.attributes.values
      end
    end

    path = "_exports/#{account_id}/#{filename}"

    s3 = AmazonS3.new
    s3.write(path, export)
    # file = File.open(File.join(Rails.root, 'tmp', filename), 'w+')
    # file << export
    # file.close
  end

  desc "Export one or more campaigns for the given account"
  task :campaigns, [:account_id, :campaign_ids] => :environment do |t, args|
    campaign_ids  = args[:campaign_ids].split(',')
    account_id    = args[:account_id]
    base_filename = "#{campaign_ids.join('-')}"

    account = Account.find account_id

    campaigns = account.campaigns.where(id: campaign_ids)
    filename  = "#{base_filename}-campaigns.csv"
    export_and_save_csv(campaigns, filename, account_id)

    [
      :caller_sessions,
      :voter_lists,
      :all_voters,
      :call_attempts,
      :transfer_attempts,
      :answers,
      :note_responses,
      :caller_groups
    ].each do |relation_name|
      campaigns.each do |campaign|
        filename = "#{base_filename}-#{relation_name}.csv"
        export_and_save_csv(campaign.send(relation_name), filename, account_id)
      end
    end

    callers = account.callers
    filename = "all-callers.csv"
    export_and_save_csv(callers, filename, account_id)

    filename = "#{base_filename}-scripts.csv"
    scripts = campaigns.map(&:script)
    export_and_save_csv(scripts, filename, account_id)

    [
      :script_texts,
      :questions,
      :notes,
      :transfers
    ].each do |relation_name|
      scripts.each do |script|
        filename = "#{base_filename}-#{relation_name}.csv"
        export_and_save_csv(script.send(relation_name), filename, account_id)
      end
    end

    # Load required records
    # Generate 1 CSV for each record type
    # - store csv in s3

    # Campaign
    # - caller_sessions
    # - voter_lists
    # - voters
    # - call_attempts
    # - transfer_attempts
    # - callers
    # - answers
    # - note_responses
    # - caller_groups
    # - script
    # - account
    # - recording

    # Script
    # - script_texts
    # - questions
    # - notes
    # - transfers
    # - campaigns
  end
end

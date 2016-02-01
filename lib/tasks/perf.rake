# encoding: utf-8

require 'uuid'

namespace :perf do
  def sorted_targets
    @sorted_targets ||= Campaign.active.to_a.sort_by{|c| c.dial_queue.available.size}
  end

  def prepare_callers
    sorted_targets.each do |campaign|
      records = campaign.callers.where(is_phones_only: false, active: true)
      if records.count.zero?
        orphan = campaign.account.callers.where(is_phones_only: false, campaign_id: nil).first
        if orphan
          orphan.campaign = campaign
          orphan.active = true
          p "Renaming orphan: #{orphan.username} on #{campaign.id}/#{campaign.account_id}"
          orphan.username = "#{orphan.username}#{rand(100)}"
          orphan.save!
        else
          username = ''
          password = ''
          alpha = %w(a b c d e f g h i j k l m n o p q r s t u v w x y z)
          12.times{ username << alpha.sample }
          12.times{ password << alpha.sample }
          orphan = campaign.account.callers.create({
            campaign_id: campaign.id,
            username: "#{username}#{rand(100)}",
            password: "#{password}#{rand(100)}"
          })
        end
      end
    end
  end

  def s3_path
    'perf_testing'
  end

  def s3
    @s3 ||= AmazonS3.new
  end

  def uuid
    @uuid ||= UUID.new
  end

  def factor
    48
  end

  def all_phones_for(campaign)
    campaign.dial_queue.available.all.select do |phone|
      house = campaign.dial_queue.households.find(phone)
      (not house.empty?) and (not house[:leads].empty?)
    end
  end

  def gen_csvs(threads, dials_per_caller=20, generate_callers=1)
    generate_callers = generate_callers > 0 ? true : false

    prepare_callers if generate_callers

    dials_file_tpl  = "dials%.csv"
    current_thread = 1

    if sorted_targets.empty?
      throw "No targets found."
    end

    sorted_targets.each do |campaign|
      break if threads <= 0

      phones          = all_phones_for(campaign)
      available_count = phones.size
      if available_count.zero?
        p "No numbers available. Campaign[#{campaign.id}] Account[#{campaign.account_id}] CurrentThread[#{current_thread}]"
        next
      end
      caller_count    = (available_count / dials_per_caller).floor
      if caller_count > threads
        caller_count = threads
      end
      threads -= caller_count

      start = 0
      stop  = dials_per_caller - 1
      caller_count.times do |caller_iter|
        if generate_callers
          caller_record = campaign.callers.where(is_phones_only: false, active: true).first
          gen_caller_csv(current_thread, caller_record)
        end

        file = "campaign_id,phone,sid,lead_uuid,answers,notes\n"
        filename = dials_file_tpl.gsub('%', "#{current_thread}")
        current_phones = phones[start..stop]
        if current_phones.nil?
          throw "Ran out of phones. Start[#{start}] Stop[#{stop}] PhoneCount[#{phones.size}] CallerIter[#{caller_iter}]"
        end
        p "Loading phones for Start[#{start}] Stop[#{stop}]"
        phones[start..stop].each do |phone|
          row = gen_dial_row(phone, campaign)
          file << row
        end
        save_csv(filename, file)

        start = stop + 1
        stop  = start + dials_per_caller - 1
        current_thread += 1
      end
    end
  end

  def gen_caller_csv(thread, caller_record)
    file_template = "callers%.csv"
    filename = file_template.gsub('%', "#{thread}")
    file = "username,password\n"
    file << "#{caller_record.username},#{caller_record.password}"
    
    save_csv(filename, file)
  end

  def gen_dial_row(phone, campaign)
    row = []
    row << campaign.id
    row << phone
    row << "CA#{uuid.generate.gsub('-','')}"
    # get lead uuid
    house = campaign.dial_queue.households.find(phone)

    if house.empty? or house[:leads].empty?
      throw "Cannot use Phone[#{phone}] because House[#{house}] Campaign[#{campaign.id}] Account[#{campaign.account_id}]"
    end

    lead = house[:leads].detect do |lead|
      not campaign.dial_queue.households.lead_completed?(lead[:sequence])
    end

    if lead.blank?
      lead = house[:leads].first
    end

    if lead[:uuid].blank?
      throw "cuz lead uuid: #{lead}"
    end
    row << lead[:uuid]
    # build answers
    answers = {}
    campaign.script.questions.each do |question|
      if question and question.possible_responses.count > 0
        answers[question.id] = question.possible_responses.sample.id
      else
        p "Skipping Question[#{question.try(:id)}] ResponseCount[#{question.try(:possible_responses).try(:count)}] Campaign[#{campaign.id}] Account[#{campaign.account_id}]"
        next
      end
    end
    row << answers.to_json
    # build notes
    notes = {}
    campaign.script.notes.each do |note|
      notes[note.id] = "This is a note for #{note.id} on #{campaign.name}"
    end
    row << notes.to_json
    CSV.generate_line(row).to_s
  end

  def save_csv(filename, file)
    p "Saving: #{s3_path}/#{filename}"
    s3.write("#{s3_path}/#{filename}", file)
  end

  task :generate_csvs, [:total_threads, :dials_per_caller, :generate_callers] => :environment do |t,args|
    total_threads    = args[:total_threads].to_i
    dials_per_caller = args[:dials_per_caller].to_i
    generate_callers = args[:generate_callers].to_i

    gen_csvs(total_threads, dials_per_caller, generate_callers)
  end

  task :download_csvs => :environment do |t,args|
    s3 = AWS::S3.new({
      access_key_id: ENV['S3_ACCESS_KEY'],
      secret_access_key: ENV['S3_SECRET_ACCESS_KEY']
    })
    bucket    = 'staging.impactdialing'
    path_glob = 'perf_testing/'
    local_path = Rails.root.join 'tmp', 'perf_fixtures'
    `mkdir -p #{local_path}`
    s3.buckets[bucket].objects.with_prefix(path_glob).each do |object|
      p "Downloading #{object.key}..."
      local_file = File.join local_path, object.key.split('/').last
      File.open(local_file, "w+:ascii-8bit") do |file|
        object.read do |chunk|
          file.write(chunk)
        end
      end
    end
  end
end

require 'uuid'

namespace :perf do
  def rich_targets
    @rich_targets ||= Campaign.active.to_a.map do |c|
      available = c.dial_queue.available.size
      if available >= 250
        [c, c.account_id, c.dial_queue.available.size]
      end
    end.compact
  end

  def callers
    @callers ||= rich_targets.map do |target|
      campaign = target.first
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
        orphan
      else
        records.first
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

  def generate_caller_csv(total_threads)
    if total_threads % 12 != 0
      throw "please pass a number of callers divisible by 12"
    end

    if callers.size * 12 < total_threads
      p "requested #{total_threads} total callers but only #{callers.size * 12} can be fulfilled"
    end

    if rich_targets.empty? or callers.empty?
      throw "no targets or callers loaded: targets[#{rich_targets.size}] callers[#{callers.size}]"
    end

    file_template = "callers%.csv"
    total_threads.times do |n|
      n += 1
      p "callers thread: #{n}"
      if n % 12 == 0
        caller_record = callers.shift
      else
        caller_record = callers.first
      end
      next if caller_record.nil?
      filename = file_template.gsub('%', "#{n}")
      file = "username,password\n"
      file << "#{caller_record.username},#{caller_record.password}"
      
      p "Saving: #{s3_path}/#{filename}"
      s3.write("#{s3_path}/#{filename}", file)
    end
  end

  def generate_dials_csv(total_threads)
    skipped          = 0
    iteration        = 0
    dials_per_thread = 20
    start            = 0
    stop             = 19
    file_template    = "dials%.csv"
    last_target      = rich_targets.first

    total_threads.times do |n|
      n += 1

      if n % 12 == 0
        target = rich_targets[iteration]
        last_target = target
        start  = 0
        stop   = 19
      else
        start  = stop + 1
        stop   = stop + dials_per_thread
        target = last_target
      end

      campaign = target.first

      file = "phone,sid,lead_uuid,answers,notes\n"
      filename = file_template.gsub('%', "#{n}")

      phones = campaign.dial_queue.available.all[start..stop]

      phones.each_with_index do |phone,index|
        row = []
        row << phone
        row << "CA#{uuid.generate.gsub('-','')}"
        # get lead uuid
        house = campaign.dial_queue.households.find(phone)

        if house.empty? or house[:leads].empty?
          p "Skipping #{phone} because House[#{house}]"
          skipped += 1
          if skipped >= 10
            throw "Skipped 10 or more households: Campaign[#{campaign.id}] Account[#{campaign.account_id}]"
          else
            next
          end
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
          answers[question.id] = question.possible_responses.sample.id
        end
        row << answers.to_json
        # build notes
        notes = {}
        campaign.script.notes.each do |note|
          notes[note.id] = "This is a note for #{note.id} on #{campaign.name}"
        end
        row << notes.to_json
        file << CSV.generate_line(row).to_s
      end
      p "Saving: #{s3_path}/#{filename}"
      s3.write("#{s3_path}/#{filename}", file)

      iteration += 1
    end
  end

  task :generate_csvs, [:total_threads] => :environment do |t,args|
    total_threads = args[:total_threads].to_i
    generate_caller_csv(total_threads)
    generate_dials_csv(total_threads)
  end
end

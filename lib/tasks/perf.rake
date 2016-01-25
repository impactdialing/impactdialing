namespace :perf do
  def rich_targets
    @rich_targets ||= Campaign.active.to_a.map do |c|
      available = c.dial_queue.available.size
      if available > 1
        [c.id, c.account_id, c.dial_queue.available.size]
      end
    end.compact
  end

  def callers
    @callers ||= rich_targets.map do |target|
      campaign = Campaign.find(target.first)
      records = campaign.callers.where(is_phones_only: false, active: true)
      if records.count.zero?
        orphan = campaign.account.callers.where(is_phones_only: false, campaign_id: nil).first
        orphan.campaign = campaign
        orphan.active = true
        orphan.save!
        orphan
      else
        records.first
      end
    end
  end

  task :generate_caller_csv, [:total_callers] => :environment do |t,args|
    total_callers = args[:total_callers].to_i
    if total_callers % 12 != 0
      throw "please pass a number of callers divisible by 12"
    end
    if callers.size * 12 < total_callers
      p "requested #{total_callers} total callers but only #{callers.size * 12} can be fulfilled"
    end
    s3            = AmazonS3.new
    file_path     = Rails.root.join 'tmp'
    s3_path       = "perf_testing"
    file_template = "callers%.csv"
    if rich_targets.empty? or callers.empty?
      throw "no targets or callers loaded: targets[#{rich_targets.size}] callers[#{callers.size}]"
    end
    total_callers.times do |n|
      n += 1
      if n % 12 == 0
        caller_record = callers.shift
      else
        caller_record = callers.first
      end
      next if caller_record.nil?
      filename = file_template.gsub('%', "#{n}")
      file = "username,password\n"
      file << "#{caller_record.username},#{caller_record.password}"
      
      s3.write("#{s3_path}/#{filename}", file)
    end
  end
end

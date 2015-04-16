# encoding: utf-8

namespace :logs do
  desc "Download logs from S3 since :date"
  task :download, [:date] => [:environment] do |t,args|
    date             = args[:date]
    year, month, day = date.split('-').map(&:to_i)
    config           = {
      'access_key_id'     => ENV['S3_ACCESS_KEY'],
      'secret_access_key' => ENV['S3_SECRET_ACCESS_KEY']
    }
    s3               = AWS::S3.new({
      :access_key_id     => config["access_key_id"],
      :secret_access_key => config["secret_access_key"]
    })
    bucket          = 'heroku-logs.impactdialing'
    papertrail_path = 'papertrail/771873'

    if month < 10
      month = "0#{month}"
    end

    stop_year, stop_month, stop_day = [Time.now.year, Time.now.month, Time.now.day].map(&:to_i)

    loop do
      ['0', '1', '2', '3'].each do |day|
        s3_path = "#{papertrail_path}/dt=#{year}-#{month}-#{day}"

        s3.buckets[bucket].objects.with_prefix(s3_path).each do |object|
          p "Downloading #{object.key}..."
          File.open(Rails.root.join("tmp/papertrail/#{object.key.split('/').last}"), "w+:ascii-8bit") do |file|
            object.read do |chunk|
              file.write(chunk)
            end
          end
        end
      end

      break if stop_month == month.to_i and stop_year == year

      if month.kind_of?(String)
        m = month.to_i + 1
        if m < 10
          month = "0#{m}"
        else
          month = m
        end
      else
        month += 1
      end
      if month == 13
        year += 1
        month = '01'
      end
    end
  end
end

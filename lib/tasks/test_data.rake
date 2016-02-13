namespace :test_data do
  desc "Build and prepare a new campaign for dialing using ImpactDialing API"
  task :prep_for_dialing,[:api_key, :api_host, :filepath] do |t,args|
    require 'aws-sdk'
    require_relative '../../app/models/amazon_s3'
    ENV['IMPACTDIALING_API_KEY'] = args[:api_key]
    ENV['IMPACTDIALING_API_HOST'] = args[:api_host]
    require_relative '../../api/examples/ruby/cli'

    filepath = args[:filepath]

    if filepath =~ /\As3.*/
      require 'tempfile'
      s3 = AmazonS3.new
      file = Tempfile.new ['s3-voter-list','.csv']
      filepath.gsub!('s3://','')
      parts = filepath.split('/')
      file << s3.object(parts.first, parts[1..-1].join('/')).read
      file.rewind
    else
      file = File.new(filepath)
    end
    cli = ImpactDialing::CLI.new
    cli.create_campaign(file)
  end
end

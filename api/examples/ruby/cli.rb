require_relative 'api'

class ImpactDialing::CLI
  class InvalidChoice < ArgumentError; end

  attr_reader :client

  include Forwardable

  delegate :scripts, to: :client
  delegate :campaigns, to: :client

  def initialize
    @client = ImpactDialing::Api::Client.new
  end

  def ask(txt)
    print "#{txt} "
    $stdin.gets.chomp
  end

  def prompt_for_choice(collection, retrying=false)
    options = send(collection)

    if options.empty?
      abort "No #{collection} to display."
    end

    unless retrying
      print "==== Please select from these #{collection} =====\n"
      options.each do |option|
        print "#{option.id}: #{option.name}\n"
      end
    end
    option_id = ask("Which one? (ID): ").to_i

    unless options.map(&:id).include?(option_id)
      print "Please choose from the available #{collection}.\n"
      raise InvalidChoice
    end
    return option_id
  end

  def ask_for_dial_mode(retrying=false)
    dial_mode = ask("Preview, Power or Predictive?: ")
    
    unless %w(Preview Power Predictive).include?(dial_mode)
      print "Please choose Preview, Power or Predictive.\n"
      raise InvalidChoice
    end
    return dial_mode
  end

  def choose_script
    with_retry(InvalidChoice) do |retrying|
      prompt_for_choice(:scripts, retrying)
    end
  end

  def choose_dial_mode
    with_retry(InvalidChoice) do |retrying|
      ask_for_dial_mode retrying
    end
  end

  def with_retry(exception_class, &block)
    retrying = false
    begin
      result = yield retrying
    rescue exception_class
      retrying = true
      retry
    end
    return result
  end

  def nameit
    defined?(Forgery) ? Forgery(:name).company_name : ask("Campaign name: ")
  end

  def create_campaign(file=nil)
    script_id = choose_script
    dial_mode = choose_dial_mode
    campaign_params = {
      name: nameit,
      caller_id: '5554441234',
      type: dial_mode,
      start_time: 3,
      end_time: 3,
      script_id: script_id,
      time_zone: 'Pacific Time (US & Canada)',
      acceptable_abandon_rate: 0.03
    }
    campaign = client.campaigns.create campaign_params

    if file
      upload_list(file, campaign.id)
    end
  end

  def choose_campaign
    with_retry(InvalidChoice) do |retrying|
      prompt_for_choice(:campaigns, retrying)
    end
  end

  def upload_list(file, campaign_id=nil)
    campaign_id ||= choose_campaign

    rows = CSV.new file.readlines.first
    file.rewind
    map = {}
    rows.each do |row|
      row.each do |header|
        field = ask "#{header.strip}:"
        # todo: make server more lenient of whitespace in headers or
        # account for it elsewhere (client?)
        map[header] = field
      end
    end
    list_params = {
      name: nameit,
      campaign_id: campaign_id,
      purpose: 'import',
      csv_to_system_map: map,
      separator: ','
    }
    file_params = {
      upload: {
        datafile: Faraday::UploadIO.new(file.path, 'text/csv')
      }
    }
    voter_lists = ImpactDialing::Api::Client::VoterLists.new(campaign_id)
    p voter_lists.create(file_params, list_params)
  end
end

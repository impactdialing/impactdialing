$environment = ARGV[0]
voter_list = ARGV[1]

root_path = File.expand_path(File.join(File.dirname(__FILE__)))
if $environment=="development"
  TWILIO_ACCOUNT = "ACc0208d4be3e204d5812af2813683243a"
  TWILIO_AUTH = "4e179c64daa7c9f5108bd6623c98aea6"
else
  TWILIO_ACCOUNT = "AC422d17e57a30598f8120ee67feae29cd"
  TWILIO_AUTH = "897298ab9f34357f651895a7011e1631"
end

ENV['BUNDLE_GEMFILE'] = "#{root_path}/Gemfile"

require 'rubygems'
require 'bundler'
Bundler.setup
require 'logger'

class Formatter

  # YYYY:MM:DD HH:MM:SS.MS daemon_name(pid) level: message
  @format = "%s %s(%d) [%s] %s\n"

  class << self
    attr_accessor :format
  end

  def call(severity, time, progname, msg)
    self.class.format % [ format_time( time ), progname, $$, severity, msg.to_s ]
  end

  private

  def format_time( time )
    time.strftime( "%Y-%m-%d %H:%M:%S." ) + time.usec.to_s
  end
end

@logger_file = "#{root_path}/log/" + $environment + ".log"
puts @logger_file
log_path = File.dirname( "./log" )
$l = Logger.new( @logger_file )
$l.formatter = Formatter.new
$l.progname = "campaign_dialer"
$l


module DaemonKit
  def self.logger
    $l
  end
  def self.env
    $environment
  end
end

require "#{root_path}/config/pre-daemonize/gems.rb"
require "#{root_path}/config/post-daemonize/database_setup.rb"
require "#{root_path}/lib/dialer-dameon.rb"

def chunk_array(array, pieces=2)
  len = array.length;
  mid = (len/pieces)
  chunks = []
  start = 0
  1.upto(pieces) do |i|
    last = start+mid
    last = last-1 unless len%pieces >= i
    chunks << array[start..last] || []
    start = last+1
  end
  chunks
end

campaigns_dialed=[]
DaemonKit.logger.info "voter_list: #{voter_list}"

def dial_voters(voter_list)
  DaemonKit.logger.info "start thread voter_list: #{voter_list.inspect}"
  #  puts "start thread voter_list: #{voter_list}"
  begin
    voter_list.each do |voter_id|
      #Voter.connection.execute("SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED") if voter_id=="16528"
      voter=Voter.find(voter_id)
      campaign=Campaign.find(voter.campaign_id)
      Thread.current["campaign"] = campaign
      DaemonKit.logger.info "calling: #{voter.Phone} (#{voter.id})"
      voter.status='Call attempt in progress'
      voter.save
      d = Dialer.startcall(voter, campaign)
      DaemonKit.logger.info "done dialing (#{voter.id})"
      campaign
    end
  rescue Exception => e
    DaemonKit.logger.info "Rescued in thread - #{ e } (#{ e.class })!"
    DaemonKit.logger.info e.backtrace
  end
end

voter_array = voter_list.split(",").each {|v| v.strip!}
if voter_array.length > 8
  voter_chucks =  chunk_array(voter_array,8) #4 threads
else
  voter_chucks = voter_array
end

threads=[]
voter_chucks.each do |chunk|
  threads<<Thread.new{dial_voters(chunk)}
end

threads.each do |t|
  t.join
  if t["campaign"]!=nil
    campaigns_dialed<< t["campaign"] if !campaigns_dialed.index(t["campaign"])
    DaemonKit.logger.info "end thread #{t["campaign"].id}"
  else
    DaemonKit.logger.info "end thread NO CAMPAIGN"
  end
  #  puts "end thread #{campaign.id}"
end


DaemonKit.logger.info "ALL THREADS JOINED"

campaigns_dialed.each do |campaign|
  campaign.calls_in_progress=false
  campaign.save
end


DaemonKit.logger.info "EXITING WITH SUCCESS"

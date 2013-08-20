require 'resque/plugins/lock'
require 'resque-loner'
require 'resque-loner'
require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"


class DeleteRecordingsJob
  include Resque::Plugins::UniqueJob
  @queue = :background_worker
  
  def self.perform
    @account_sid = 'AC422d17e57a30598f8120ee67feae29cd'
    @auth_token = "897298ab9f34357f651895a7011e1631"
    @client = Twilio::REST::Client.new(@account_sid, @auth_token)
    @account = @client.account
    rec = ""
    1.times do |x|
      @account.recordings.list({"DateCreated<" =>"2012-06-31",  "DateCreated>" => "2012-06-01",:page => x, :page_size => 1}).each do |r|
        rec = r
      end
    end
    
    EM.synchrony do
      2.times do |x|
        recordings = @account.recordings.list({"DateCreated<" =>"2012-11-31",  "DateCreated>" => "2011-01-01",:page => x, :page_size => 1000})      
        concurrency = 1000
        EM::Synchrony::Iterator.new(recordings, concurrency).map do |recording, iter|
          http =     EventMachine::HttpRequest.new("https://api.twilio.com/2010-04-01/Accounts/#{@account_sid}/Recordings/#{recording.sid}.json").delete :head => {'authorization' => [@account_sid, @auth_token]}
          http.callback { 
            iter.return(http)
            }        
          http.errback { iter.return(http) }
        end
      end
      EventMachine.stop
      
    end
    
    
  end
end

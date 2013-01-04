require 'resque/plugins/lock'
require 'resque-loner'

class DeleteRecordingsJob
  include Resque::Plugins::UniqueJob
  @queue = :background_worker
  
  def self.perform
    @account_sid = 'AC422d17e57a30598f8120ee67feae29cd'
    @auth_token = "897298ab9f34357f651895a7011e1631"
    @client = Twilio::REST::Client.new(@account_sid, @auth_token)
    @account = @client.account
    100.times do |x|
      @account.recordings.list({"DateCreated<" =>"2012-11-31",  "DateCreated>" => "2011-01-01",:page => x, :page_size => 10}).each do |r|
        r.delete
      end
    end
    
  end
end

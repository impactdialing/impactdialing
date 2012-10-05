require Rails.root.join("jobs/heroku_resque_auto_scale")
require 'resque/plugins/lock'
require 'resque-loner'
require 'net/http'
require 'uri'


class CorruptedDynoJob 
  extend Resque::Plugins::Lock
  include Resque::Plugins::UniqueJob
  @queue = :background_worker
  
   def self.perform()
     dynos_hash = corrupted_dynos(h12_logs).inject(Hash.new(0)) {|h,i| h[i] += 1; h }     
     total = dynos_hash.values.inject(0){|sum,x| sum+x}
     dynos_hash.each_pair do |dyno, error_count|       
         HerokuResqueAutoScale::Scaler.restart_web_dyno("web."+dyno) if (error_count*100/total) > 50
     end          
   end
   
   def self.h12_logs
     url = URI.parse('http://herokuapp2088358.loggly.com/api/search?q=H12&from=NOW-10minutes')
     request = Net::HTTP::Get.new(url.request_uri)
     request.basic_auth 'app2088358', 'X~a$B2!'
     response = Net::HTTP.start(url.host, url.port) {|http| http.request(request)}
     JSON.parse(response.body)     
   end
   
   def self.corrupted_dynos(logs)
     corrupted_web_dynos = []
     logs["data"].each do |h12_error|
       error_text = h12_error["text"]
       corrupted_web_dynos << error_text.slice(error_text.index("web")+4..error_text.index("web")+4)
     end     
     corrupted_web_dynos
   end
end

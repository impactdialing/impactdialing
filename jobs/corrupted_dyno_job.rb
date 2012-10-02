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
     url = URI.parse('http://herokuapp2088358.loggly.com/api/search?q=H12&from=NOW-10minutes')
     request = Net::HTTP::Get.new(url.request_uri)
     request.basic_auth 'app2088358', 'X~a$B2!'
     response = Net::HTTP.start(url.host, url.port) {|http| http.request(request)}
     json_response = JSON.parse(response.body)
     corrupted_web_dynos = []
     json_response["data"].each do |h12_error|
       error_text = h12_error["text"]
       corrupted_web_dynos << error_text.slice(error_text.index("web")+4..error_text.index("web")+4)
     end
     dynos_hash = corrupted_web_dynos.inject(Hash.new(0)) {|h,i| h[i] += 1; h }
     total = dynos_hash.values.inject(0){|sum,x| sum+x}
     dynos_hash.each_pair do |dyno, error_count|
       if (error_count*100/total) > 50
         HerokuResqueAutoScale::Scaler.restart_web_dyno("web."+dyno)
       end
     end     
   end
end

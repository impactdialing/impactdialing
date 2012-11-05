JOBS_ROOT = File.expand_path('..', __FILE__)
class ParseVoxeoData
  
  def self.perform(file_name)
    puts JOBS_ROOT
    file = File.open(JOBS_ROOT + "/#{file_name}", "rb")
    
    reader = Nokogiri::XML::Reader(file)
    reader.each do |node|
      if node.attribute("direction") == "inbound"
        start_time = node.attribute("startDate") + " " + node.attribute("startTime")
        end_time = Time.parse(start_time) + (node.attribute("durationMinutes").to_f * 60)
        puts " #{node.attribute("direction")} - #{node.attribute('sessionId')} - #{start_time}  - #{end_time}  - #{node.attribute("durationMinutes")} "         
        begin
          caller_session = CallerSession.find_by_sid(node.attribute('sessionId'))
          caller_session.update_attributes(starttime: start_time, tStartTime: start_time, endtime: end_time, tEndTime: end_time)        
        rescue
        end
      end
    end
  end
end
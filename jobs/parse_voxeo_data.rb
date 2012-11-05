JOBS_ROOT = File.expand_path('..', __FILE__)
class ParseVoxeoData
  
  def self.perform(file_name)
    puts JOBS_ROOT
    file = File.open(JOBS_ROOT + "/#{file_name}", "rb")
    contents = file.read
    sessions_array =  Hash.from_xml(contents)["sessions"]["session"]
    sessions_array.each do |session|
      if session['applicationName'] == 'inboundConference'        
        start_time = session['startDate'] + " " + session['startTime']
        end_time = Time.parse(start_time) + session['durationMinutes'].to_f
        puts " #{session['direction']} - #{session['sessionId']} - #{start_time}  - #{end_time}  - #{session['durationMinutes']} "         
        caller_session = CallerSession.find_by_sid(session['sessionId'])
        caller_session.update_attributes(starttime: starttime, tStartTime: starttime, end_time: end_time, tEndTime: end_time)
      end
    end
   # 2012-11-02 - 17:58:32 - 32.2 
  end
end
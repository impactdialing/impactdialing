require 'rubygems'
require 'active_record'
$config = YAML.load_file("./config/database.yml")


class CallAttempt < ActiveRecord::Base
  establish_connection $config['development'];
#    set_table_name 'calls'
end

class Dump < ActiveRecord::Base
  establish_connection $config['development'];
end

#puts CallAttempt.first

module SQLLite
  class Request < ActiveRecord::Base
    establish_connection $config['production2']
    set_table_name 'requests'
  end
  class Completed < ActiveRecord::Base
    establish_connection $config['production2']
    set_table_name 'completed_lines'
  end
  class Params < ActiveRecord::Base
    establish_connection $config['production2']
    set_table_name 'parameters_lines'
  end
end

#reqs = SQLLite::Request.all(:limit=>2500)
#reqs = SQLLite::Request.find_all_by_id(118)
reqs = SQLLite::Request.all
reqs.each do |req|
  d=Dump.new
  d.request_id=req.id
  d.first_line=req.first_lineno
  d.last_line=req.last_lineno
  c = SQLLite::Completed.find_by_request_id(req.id)
  if !c.blank?
    d.completed_id=c.id
    d.completed_lineno=c.lineno
    d.duration=c.duration
    d.status=c.status
    d.url=c.url
  end
  if !d.url.nil? && !d.url.index("monitor") 
    p = SQLLite::Params.find_by_request_id(req.id)
    d.params_id=p.id
    d.params_line=p.lineno
    d.params=p.params
    #d.guid
    #d.save
  
    begin
      y = YAML.load(d.params)
      d.guid = y[:CallSid]
    rescue
    end
    d.save
  else
  end
end

# To import tickets, just do this!
# Collaboa::Ticket.find(:all, :conditions => {:status_id => 1, :project_id => 1}).each do |t|
#   Trac::Ticket.create(:summary => t.summary, :description => t.content, :time => Time.now)
# end

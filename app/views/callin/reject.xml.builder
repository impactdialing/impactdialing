xml.instruct! :xml, :version=>"1.0" 
xml.Response("version"=>"1.0") do |response|
  xml.Reject("reason"=>"busy")
end

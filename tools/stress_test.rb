require 'mechanize'

def input_value(page, attr, value)
  page.search(".//input[@#{attr}='#{value}']").first.attributes["value"].value
end

100.times do
  t = Thread.new do
    agent = Mechanize.new
    page = agent.get('http://staging.impactdialing.com/caller/login')
    form = page.form_with(id: 'loginForm')
    form.email = "kesha1@impactdialing.com"
    form.password = "password"
    caller_page = form.submit
    session_key = input_value(caller_page, 'name', 'session_key')
    caller_id = input_value(caller_page, 'name', 'caller')
    campaign_id = input_value(caller_page, 'name', 'campaign')

    agent.post("/caller/#{caller_id}/check_reassign", campaign_id: campaign_id, session_key: session_key, protocol: "http://")

    twilio_agent = Mechanize.new
    twilio_agent.post('http://impactdialing-staging.herokuapp.com/caller/start_calling', {
      "AccountSid"     => "[FILTERED]",
      "ApplicationSid" => "AP9a7f90ed206c430587a5c534c02a558f",
      "CallStatus"     => "ringing",
      "caller_id"      => "77",
      "To"             => "",
      "Called"         => "",
      "PhoneNumber"    => "6502626881",
      "campaign_id"    => "121",
      "Direction"      => "inbound",
      "ApiVersion"     => "2010-04-01",
      "Caller"         => "",
      "CallSid"        => "CA53bc12c3a30831b27d45514853271e0d",
      "From"           => "",
      "session_key"    => "d6a6dd4cb0c6dd375a380f2a355386f0e234fb7f"
    })
  end
  t.join
end

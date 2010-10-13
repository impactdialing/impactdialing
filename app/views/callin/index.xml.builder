xml.instruct! :xml, :version=>"1.0" 
xml.Response("version"=>"1.0") do |response|

  if @publish_channel
    xml.Publish("channel"=>"#{@publish_channel}") {
      xml.Data("name"=>"#{@publish_key}", "value"=>"#{@publish_value}")
    }
  end
  if @pause>0
    xml.Pause("length"=>@pause)
  end
  if @redirect
    xml.Redirect(@redirect)
  end
	if @gather
	  if @gatherPost.blank?
  		xml.Gather("timeout"=>"#{@gathertimeout}","numDigits"=>"#{@numDigits}", "finishOnKey"=>@finishOnKey, "method"=>"POST"){
        xml.Play("#{@play}") if @play
      	xml.Say("#{@say}") if @say
  		}
    else
  		xml.Gather("timeout"=>"#{@gathertimeout}","numDigits"=>"#{@numDigits}", "finishOnKey"=>@finishOnKey, "method"=>"POST", "action"=>@gatherPost){
        xml.Play("#{@play}") if @play
      	xml.Say("#{@say}") if @say
  		}
    end
	else
    xml.Play("#{@play}") if @play
    xml.Play("#{@play2}") if @play2
  	xml.Say("#{@say}") if @say
	end
  if @endpause>0
    xml.Pause("length"=>@endpause)
  end

	xml.Hangup if @hangup
  if @repeatRedirect
    xml.Redirect(@repeatRedirect)
  end
end
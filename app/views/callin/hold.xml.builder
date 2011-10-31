xml.instruct! :xml, :version=>"1.0" 
xml.Response("version"=>"1.0") do |response|
 xml.Play("#{APP_URL}/wav/hold.mp3")
 xml.Redirect('method' => 'GET')
end

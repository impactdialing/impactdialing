class VoterListApiStrategy
  require 'net/http'
  
  def initialize(account_id, campaign_id, callback_url)
    @account_id = account_id
    @campaign_id = campaign_id
    @callback_url = callback_url
  end
  
  def response(response, params)
    uri = URI.parse(@callback_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl=true
    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data({message: response, account_id: @account_id, campaign_id: @campaign_id, list_name: params[:voter_list_name]})
    http.start{http.request(request)}
  end
  
end
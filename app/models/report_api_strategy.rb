class ReportApiStrategy
  require 'net/http'
  
  def initialize(result, account_id, campaign_id, callback_url)
    @result = result
    @account_id = account_id
    @campaign_id = campaign_id
    @callback_url = callback_url
  end
  
  def response(params)
    if @result == "success"
      expires_in_24_hours = (Time.now + 24.hours).to_i
      link = AWS::S3::S3Object.url_for("#{params[:campaign_name]}.csv", "download_reports", :expires => expires_in_24_hours)
    else
      link = ""
    end
    uri = URI.parse(@callback_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl=true
    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data({message: @result, download_link: link, account_id: @account_id, campaign_id: @campaign_id})
    http.start{http.request(request)}
  end
  
end

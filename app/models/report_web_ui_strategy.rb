class ReportWebUIStrategy

  def initialize(result, user, campaign, exception)
    @result = result
    @mailer = UserMailer.new
    @user = user
    @campaign = campaign
    @exception = exception
  end


  def response(params)
    if @result == "success"
      expires_in_24_hours = (Time.now + 24.hours).to_i
      link = AmazonS3.new.object("download_reports", "#{params[:campaign_name]}.csv").url_for(:read, :expires => (Time.now + 24.hours).to_i).to_s
      DownloadedReport.using(:master).create(link: link, user: @user, campaign_id: @campaign.id)
      @mailer.deliver_download(@user, link)
    else
      @mailer.deliver_download_failure(@user, @campaign, @campaign.account_id, @exception) unless Rails.env.development?
    end
  end

end

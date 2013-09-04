##
# +result+:: String(success|failure)
# +user+:: User instance
# +campaign+:: Campaign instance
# +exception+:: Exception instance or nil
#
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
      link = AmazonS3.new.object("download_reports", "#{params[:campaign_name]}.csv").url_for(:read, :expires => 24.hours.to_i).to_s
      DownloadedReport.using(:master).create(link: link, user: @user, campaign_id: @campaign.id)
      @mailer.deliver_download(@user, link)
    else
      unless Rails.env.development?
        # notify the end-user
        @mailer.deliver_download_failure(@user, @campaign)
        # notify us
        notes = "Campaign: #{@campaign.name}; Account ID: #{@campaign.account_id}"
        @mailer.deliver_exception_notification(notes, @exception)
      end
    end
  end

end

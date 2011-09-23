class Postoffice < ActionMailer::Base
  def password_recovery(user)
    @subject = "ImpactDialing.com password recovery"
    @recipients = user.email
    @from = 'no-reply@impactdialing.com'
    @sent_on = Time.now
    @body["reset_code"] = user.password_reset_code
    @body["email"] = user.email
    @headers = {}
  end

  def feedback(issue)
    @subject = "ImpactDialing.com feedback"
    if RAILS_ENV == 'production'
      @recipients = "beans@beanserver.net, michael@impactdialing.com"
    else
      @recipients = "beans@beanserver.net"
    end
    @from = 'no-reply@impactdialing.com'
    @sent_on = Time.now
    @body["issue"] = issue
    @headers = {}
  end
end

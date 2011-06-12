class Postoffice < ActionMailer::Base
  def password_recovery(user)
        @subject = "ImpactDialing.com password recovery"
        @recipients = user.email
        @from = 'no-reply@impactdialing.com'
        @sent_on = Time.now
  	    @body["password"] = user.password
  	    @body["email"] = user.email
        @headers = {}
   end  
   def feedback(issue)
         @subject = "ImpactDialing.com feedback"
         @recipients = "beans@beanserver.net,michael@impactdialing.com"
         @from = 'no-reply@impactdialing.com'
         @sent_on = Time.now
   	    @body["issue"] = issue
         @headers = {}
    end  

end

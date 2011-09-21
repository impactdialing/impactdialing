class UserMailer
  def initialize
    @uakari = Uakari.new(MAILCHIMP_API_KEY)
  end

  def deliver_invitation(new_user, current_user)
    emailText = "Click here to reset your password<br/> #{ reset_password_url(:reset_code => user.password_reset_code) }"
    u.send_email({
      :track_opens => true,
      :track_clicks => true,
      :message => {
        :subject => "Invited to #{I18n.t(:title)} by #{current_user.email}",
        :html => emailText,
        :text => emailText,
        :from_name => I18n.t(:title),
        :from_email => current_user.email,
        :to_email => [new_user.email]
      }
    })
  end
end

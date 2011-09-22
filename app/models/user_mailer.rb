class UserMailer
  include ActionController::UrlWriter

  def initialize
    @uakari = Uakari.new(MAILCHIMP_API_KEY)
  end

  def deliver_invitation(new_user, current_user)
    link = reset_password_url(:host => HOST, :port => PORT, :reset_code => new_user.password_reset_code)
    email_text = "Click here to reset your password<br/> #{ link }"
    @uakari.send_email({
      :track_opens => true,
      :track_clicks => true,
      :message => {
        :subject => "Invited to #{I18n.t(:title)} by #{current_user.email}",
        :html => I18n.t(:admin_invite_body_html, :domain => I18n.t(:title), :link => link),
        :text => I18n.t(:admin_invite_body_text, :domain => I18n.t(:title), :link => link),
        :from_name => I18n.t(:title),
        :from_email => current_user.email,
        :to_email => [new_user.email]
      }
    })
    RAILS_DEFAULT_LOGGER.info email_text
  end
end

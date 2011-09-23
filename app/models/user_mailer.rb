class UserMailer
  include ActionController::UrlWriter
  include WhiteLabeling

  def initialize
    @uakari = Uakari.new(MAILCHIMP_API_KEY)
  end

  def deliver_invitation(new_user, current_user)
    link = reset_password_url(:host => HOST, :port => PORT, :reset_code => new_user.password_reset_code)
    title =
    @uakari.send_email({
      :track_opens => true,
      :track_clicks => true,
      :message => {
        :subject => I18n.t(:admin_invite_subject, :title => white_labeled_title(current_user.domain)),
        :html => I18n.t(:admin_invite_body_html, :title => white_labeled_title(current_user.domain), :link => link),
        :text => I18n.t(:admin_invite_body_text, :title => white_labeled_title(current_user.domain), :link => link),
        :from_name => I18n.t(:title),
        :from_email => current_user.email,
        :to_email => [new_user.email]
      }
    })
  end
end

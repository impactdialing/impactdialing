class DeliverInvitationEmailJob
  @queue = :background_worker


  def self.perform(new_user_id, current_user_id)
    new_user = User.find(new_user_id)
    current_user = User.find(current_user_id)
    user_mailer = UserMailer.new
    user_mailer.deliver_invitation(new_user, current_user)
  end
end
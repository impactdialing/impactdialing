##
# What it says on the box, delivers an invitation email to a new user.
# Queued from +UsersController#invite+.
#
# ### Metrics
#
# - completed
# - failed
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 failure
#
class DeliverInvitationEmailJob
  @queue = :background_worker


  def self.perform(new_user_id, current_user_id)
    new_user = User.find(new_user_id)
    current_user = User.find(current_user_id)
    user_mailer = UserMailer.new
    user_mailer.deliver_invitation(new_user, current_user)
  end
end
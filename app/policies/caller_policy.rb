class CallerPolicy < ApplicationPolicy

  def archived?
    admin?
  end

  def restore?
    admin?
  end

  def reassign_to_campaign?
    current_user?
  end

  def usage?
    current_user?
  end

  def call_details?
    current_user?
  end
end

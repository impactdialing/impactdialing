class CampaignPolicy < ApplicationPolicy
  def archived?
    admin?
  end

  def restore?
    admin?
  end

  def can_change_script?
    admin?
  end
end

class ScriptPolicy < ApplicationPolicy

  def questions_answered?
    admin?
  end

  def possible_responses_answered?
    admin?
  end

  def archived?
    admin?
  end

  def restore?
    admin?
  end
end

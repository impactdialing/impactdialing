class NavigationPolicy < Struct.new(:user, :navigation)

  def initialize(user, navigation)
    @user = user
    @navigation = navigation
  end
  def show?
    if @user.administrator?
      true
    else @user.supervisor?
      false
    end
  end
end

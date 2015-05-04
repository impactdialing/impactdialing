class NavigationPolicy < Struct.new(:user, :navigation)

  def initialize(user, navigation)
    @user = user
    @navigation = navigation
  end

  def user_administrator?
    @user.administrator?
  end

  #methods for scripts,campaigns, and callers
end

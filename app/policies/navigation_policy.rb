class NavigationPolicy < Struct.new(:user, :navigation)

  def initialize(user, navigation)
    @user = user
    @navigation = navigation
  end

  def show?
    # @user.administrator?
    false
  end
end

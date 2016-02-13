module WebLoginHelpers
  def login_as(user)
    allow(@controller).to receive(:current_user).and_return(user)
    session[:user] = user.id
    session[:caller] = user.id
  end

  def http_login
    name = AdminController::USER_NAME
    password = AdminController::PASSWORD
    if page.driver.respond_to?(:basic_auth)
      page.driver.basic_auth(name, password)
    elsif page.driver.respond_to?(:basic_authorize)
      page.driver.basic_authorize(name, password)
    elsif page.driver.respond_to?(:browser) && page.driver.browser.respond_to?(:basic_authorize)
      page.driver.browser.basic_authorize(name, password)
    else
      raise "I don't know how to log in!"
    end
  end

  def create_user_and_login
    user = build :user
    visit '/client/login'
    fill_in 'Email address', :with => user.email
    fill_in 'Pick a password', :with => user.new_password
    click_button 'Sign up'
    click_button 'I and the company or organization I represent accept these terms.'
  end

  def web_login_as(user)
    # fail early if db was cleaned
    expect(User.find(user.id)).to eq user

    visit '/client/login'
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password'
    click_on 'Log in'
    expect(page).to_not have_content 'The email or password you entered was incorrect. Please try again.'
  end

  def caller_login_as(caller)
    visit '/caller/login'
    fill_in 'Username', with: caller.username
    fill_in 'Password', with: caller.password
    click_on 'Log in'
  end

  def fixture_path
    Rails.root.join('spec/fixtures/').to_s
  end
end

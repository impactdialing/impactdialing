def capybara_switch_to_webkit
  unless ENV['USE_SAUCE']
    Capybara.javascript_driver = :webkit
    if Capybara.page.driver.respond_to? :allow_url
      Capybara.page.driver.allow_url("js.stripe.com")
      Capybara.page.driver.allow_url("static.twilio.com")
      Capybara.page.driver.allow_url("api.stripe.com")
      Capybara.page.driver.allow_url("api.usersnap.com")
      Capybara.page.driver.allow_url("d3mvnvhjmkxpjz.cloudfront.net")
      Capybara.page.driver.allow_url("d3dy5gmtp8yhk7.cloudfront.net")
      Capybara.page.driver.allow_url("beacon.errorception.com")
      Capybara.page.driver.allow_url("stats.pusher.com")
      Capybara.page.driver.allow_url("d2wy8f7a9ursnm.cloudfront.net")
    end
  end
end


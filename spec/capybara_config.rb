Capybara::Webkit.configure do |config|
  config.allow_url("js.stripe.com")
  config.allow_url("q.stripe.com")
  config.allow_url("static.twilio.com")
  config.allow_url("api.stripe.com")
  config.allow_url("api.usersnap.com")
  config.allow_url("d3mvnvhjmkxpjz.cloudfront.net")
  config.allow_url("d3dy5gmtp8yhk7.cloudfront.net")
  config.allow_url("beacon.errorception.com")
  config.allow_url("stats.pusher.com")
  config.allow_url("d2wy8f7a9ursnm.cloudfront.net")
end

module CapybaraConfig
  def self.switch_to_webkit
    switch(:webkit)
  end

  def self.switch_to_selenium
    switch(:selenium)
  end

  def self.switch(to)
    return if ENV['USE_SAUCE']
    Capybara.javascript_driver = to
  end
end

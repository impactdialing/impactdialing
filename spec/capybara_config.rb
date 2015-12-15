require 'selenium/webdriver/remote/http/persistent'

module CapybaraConfig
  def self.switch_to_webkit
    return if ENV['USE_SAUCE']
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

  def self.register_sauce_driver
    url  = [
      "http://#{ENV['SAUCE_USERNAME']}:#{ENV['SAUCE_ACCESS_KEY']}",
      "@ondemand.saucelabs.com:80/wd/hub"
    ].join
    caps = Selenium::WebDriver::Remote::Capabilities.new

    case ENV['USE_SAUCE']
    when 'ie11'
      Capybara.default_wait_time     = 30
      caps.platform                  = 'Windows 10'
      caps.version                   = '11'
      #caps['ie.ensureCleanSession'] = true
    end
    caps['build']        = ENV['CIRCLE_SHA1']
    Capybara.server_port = 6543

    time            = Time.now.to_i
    new_driver_name = "sauce_#{time}".to_sym
    Capybara.register_driver(new_driver_name) do |app|
      http_client = Selenium::WebDriver::Remote::Http::Persistent.new
      http_client.timeout = 300
      opts = {
        browser: :remote,
        url: url,
        desired_capabilities: caps,
        http_client: http_client
      }
      Capybara::Selenium::Driver.new(app, opts)
    end

    Capybara.default_driver    = new_driver_name
    Capybara.javascript_driver = new_driver_name
  end
end


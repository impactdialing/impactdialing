# You should edit this file with the browsers you wish to use
# For options, check out http://saucelabs.com/docs/platforms
require 'sauce'
require 'sauce/capybara'

Sauce.config do |config|
  config[:start_local_application]    = false
  config[:start_tunnel]               = (not ENV['CIRCLE_SHA1'])
  config[:sauce_connect_4_executable] = "#{ENV['HOME']}/sc-bin/bin/sc"

  shared_caps = {
    build: ENV['CIRCLE_SHA1'] || "dev-#{Time.now.to_i}"
  }
  ie_caps = shared_caps.merge({
    'ie.ensureCleanSession' => true
  })
  winlt10_caps = ie_caps.merge({
    'iedriverVersion' => 'x64_2.46.0'
  })

  browsers = {
    'ie' => [
      ['Windows 7','Internet Explorer','9', winlt10_caps],
      ['Windows 8','Internet Explorer','10', winlt10_caps],
      ['Windows 8.1','Internet Explorer','11', winlt10_caps],
      # todo: support msft edge (driver errors out)
      #['Windows 10','MicrosoftEdge','20.10240', ie_caps],
    ],
    'ch' => [
      ['Windows 8.1','Chrome','46', shared_caps],
      ['OS X 10.10','Chrome','46', shared_caps],
      ['Linux','Chrome','46', shared_caps],
    ],
    'ff' => [
      ['Windows 8','Firefox','40', shared_caps],
      ['OS X 10.10','Firefox','40', shared_caps],
      ['Linux','Firefox','40', shared_caps],
    ],
    'sa' => [
      ['OS X 10.9','Safari','7', shared_caps],
      ['OS X 10.10','Safari','8', shared_caps],
      ['OS X 10.11','Safari','9', shared_caps]
    ]
  }
  browser = browsers[ENV['USE_SAUCE']]
  throw "Unknown browser: #{ENV['USE_SAUCE']}, test run aborted." if browser.nil?

  config[:browsers] = browser
end

Capybara.default_driver = :sauce
Capybara.javascript_driver = :sauce
Capybara.default_wait_time = 30

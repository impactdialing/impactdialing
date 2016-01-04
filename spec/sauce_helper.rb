# You should edit this file with the browsers you wish to use
# For options, check out http://saucelabs.com/docs/platforms
require 'sauce'
require 'sauce/capybara'

Sauce.config do |config|
  config[:start_local_application]    = false
  config[:start_tunnel]               = (not ENV['CIRCLE_SHA1'])
  config[:sauce_connect_4_executable] = "#{ENV['HOME']}/sc-bin/bin/sc"

  #config[:browsers]                = [
    #['Windows 8','Internet Explorer','10'],
    #['Windows 8.1','Internet Explorer','11'],
    #['Windows 7','Internet Explorer','9'],
    #['Windows 7','Internet Explorer','10'],
    #['Windows 7','Internet Explorer','11'],
    #['Windows 10','Internet Explorer','11'],
    #['Windows 8','Firefox','40'],
    #['Windows 8','Chrome','46'],
    #['Linux','Chrome','46'],
    #['Linux','Firefox','40'],
    #['OS X 10.10','Firefox','40'],
    #['OS X 10.10','Chrome','46'],
    #['OS X 10.9','Safari','7'],
    #['OS X 10.10','Safari','8'],
    #['OS X 10.11','Safari','9']
  #]
  browsers = {
    'ie11' => ['Windows 8.1', 'Internet Explorer', '11'],
    'ie10' => ['Windows 7', 'Internet Explorer', '10'],
    'ie9' => ['Windows 7', 'Internet Explorer', '9'],
    'ch' => ['Windows 7', 'Chrome', nil],
    'ff' => ['Windows 10', 'Firefox', 40],
    'sa7' => ['OS X 10.9', 'Safari', '7'],
    'sa9' => ['OS X 10.10', 'Safari', '9'],
    'lch' => ['Linux', 'Chrome', nil],
    'lff' => ['Linux', 'Firefox', 40]
  }
  browser = browsers[ENV['USE_SAUCE']]
  raise "Unknown browser: #{ENV['USE_SAUCE']}, test run aborted." if browser.nil?
end

Capybara.default_driver = :sauce
Capybara.javascript_driver = :sauce
Capybara.default_wait_time = 30
# CapybaraConfig.register_sauce_driver

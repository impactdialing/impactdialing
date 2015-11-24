if Rails.env.test?
  require 'webmock'
  WebMock.allow_net_connect!
end

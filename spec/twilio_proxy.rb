require 'rspec/rails'
class TwilioProxy

  def initialize
    @conn = Faraday.new(:url => 'http://localhost:3000')
  end

  def callin
    @conn.post '/callin/create'
    @conn
  end

  def identify(digits)
    callin.post '/callin/identify?attempt=1', { Digits: digits }
    @conn
  end


end
